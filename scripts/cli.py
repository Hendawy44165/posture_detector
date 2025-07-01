"""
Posture Detection CLI
--------------------
A production-ready interface for streaming posture detection results as JSON.

This CLI acts as a server that continuously monitors posture through a camera
and streams the results as JSON lines over stdout. It's designed to be used
as a long-running process that can be managed by parent processes (e.g., Flutter apps).

JSON Output Format:
    Posture Results:
        {
            "timestamp": float,      # Unix timestamp
            "type": "posture",       # Message type
            "code": 0,               # Success = 0
            "is_leaning": bool,      # True if leaning detected
            "posture": str          # "leaning" or "upright"
        }

    Status Messages:
        {
            "timestamp": float,      # Unix timestamp
            "type": "status",        # Message type
            "code": int,             # Status code (0 = OK)
            "message": str          # Status description
        }

    Error Messages:
        {
            "timestamp": float,      # Unix timestamp
            "type": "error",         # Message type
            "code": int,             # Error code (see below)
            "message": str          # Error description
        }

Error Codes:
    1: General error
    2: Camera subscription error
    3: Posture detection error
    10: Camera hardware/access error
    99: Unexpected system error

Usage:
    python cli.py [--interval SECONDS] [--camera INDEX]
                 [--sensitivity FLOAT] [--verbose]

Example:
    python cli.py --interval 2.0 --sensitivity 0.4 --camera 1 --verbose
"""

import sys
import json
import time
import signal
import argparse
import logging
from typing import Dict, Any
from contextlib import contextmanager

from camera_monitor import CameraMonitor


class PostureStreamCLI:
    """
    A production-ready CLI for streaming posture detection results.

    This class manages the lifecycle of posture detection monitoring and provides
    a robust streaming interface via stdout. It handles graceful shutdown,
    proper error reporting, and maintains a stable streaming connection.

    The CLI follows these principles:
    1. Reliability: Continues running despite recoverable errors
    2. Clear Communication: All output is well-structured JSON
    3. Proper Resource Management: Graceful shutdown and cleanup
    4. Detailed Logging: Comprehensive logging for debugging
    """

    def __init__(self, interval: float, camera_index: int, sensitivity: float, verbose: bool = False):
        """
        Initialize the streaming CLI with monitoring parameters.

        Args:
            interval: Seconds between posture checks
            camera_index: Index of the camera device to use
            sensitivity: Posture detection sensitivity (0.0-1.0)
            verbose: Enable debug logging to stderr
        """
        self.monitor = CameraMonitor(interval=interval, camera_index=camera_index, sensitivity=sensitivity)
        self.verbose = verbose
        self.running = True
        self.subscriber_id = id(self)
        self._setup_logging()

        # Set up graceful shutdown handlers
        signal.signal(signal.SIGINT, self._signal_handler)
        signal.signal(signal.SIGTERM, self._signal_handler)

    def run(self) -> int:
        """
        Main execution loop that streams posture detection results.

        The loop continues until explicitly stopped via signal or error.
        All results and errors are reported as JSON via stdout.

        Returns:
            int: Exit code (0 for success, 1 for error)
        """
        try:
            self.logger.info("Starting posture monitoring...")
            self._output_status("Starting posture monitoring")

            with self._error_context("camera monitor subscription", code=2):
                stream = self.monitor.subscribe(self.subscriber_id)

            self.logger.info("Camera monitor active")
            self._output_status("Camera monitor active")

            while self.running:
                try:
                    is_leaning = next(stream)
                    if is_leaning is None:
                        raise RuntimeError("Posture detection failed, no result returned")
                    timestamp = time.time()
                    self._output_posture(is_leaning, timestamp)
                    self.logger.debug(f"Posture detected: {'leaning' if is_leaning else 'upright'}")
                except StopIteration:
                    break
                except Exception as e:
                    # Catch all errors from camera_monitor or posture_detector
                    self._output_error(f"Posture detection error: {e}", code=3)
                    self.logger.error(f"Posture detection error: {e}")
                    time.sleep(self.monitor.interval)
            return 0

        except RuntimeError as e:
            self._output_error(f"Camera hardware error: {str(e)}", code=10)
            return 1
        except Exception as e:
            self._output_error(f"Unexpected error: {str(e)}", code=99)
            return 1
        finally:
            self._cleanup()

    def _cleanup(self):
        """Perform cleanup operations before shutdown."""
        try:
            self.monitor.unsubscribe(self.subscriber_id)
            self.logger.info("Unsubscribed from camera monitor")
            self._output_status("Posture monitoring stopped")
        except Exception as e:
            self.logger.error(f"Error during cleanup: {e}")

    def _setup_logging(self):
        """Configure logging to stderr with appropriate verbosity level."""
        level = logging.DEBUG if self.verbose else logging.WARNING
        logging.basicConfig(
            level=level, format="%(asctime)s - %(levelname)s - %(message)s", stream=sys.stderr, force=True
        )
        self.logger = logging.getLogger(__name__)

    def _signal_handler(self, signum: int, frame=None):
        """Handle shutdown signals gracefully."""
        self.logger.info(f"Received signal {signum}, shutting down...")
        self.running = False

    @contextmanager
    def _error_context(self, operation: str, code: int = 1):
        """
        Context manager for consistent error handling and reporting.
        Catches and reports errors without interrupting the stream.

        Args:
            operation: Description of the operation being performed
            code: Error code to use in JSON output
        """
        try:
            yield
        except KeyboardInterrupt:
            self.logger.info("Keyboard interrupt received")
            self.running = False
        except Exception as e:
            error_msg = f"Error during {operation}: {str(e)}"
            self.logger.error(error_msg)
            self._output_error(error_msg, code=code)

    def _write_json(self, data: Dict[str, Any]):
        """
        Write JSON data to stdout with proper flushing.

        Args:
            data: Dictionary to serialize as JSON
        """
        try:
            sys.stdout.write(json.dumps(data, separators=(",", ":")) + "\n")
            sys.stdout.flush()
        except (IOError, OSError) as e:
            self.logger.error(f"Failed to write JSON output: {e}")
            self.running = False

    def _output_error(self, message: str, code: int = 1):
        """Output error message as JSON."""
        self._write_json({"timestamp": time.time(), "type": "error", "code": code, "message": message})

    def _output_status(self, message: str, code: int = 0):
        """Output status update as JSON."""
        self._write_json({"timestamp": time.time(), "type": "status", "code": code, "message": message})

    def _output_posture(self, is_leaning: bool, timestamp: float):
        """Output posture detection result as JSON."""
        self._write_json(
            {
                "timestamp": timestamp,
                "type": "posture",
                "code": 0,
                "is_leaning": is_leaning,
                "posture": "leaning" if is_leaning else "upright",
            }
        )


def parse_args() -> argparse.Namespace:
    """Parse and validate command-line arguments."""
    parser = argparse.ArgumentParser(
        description="Stream posture detection results as JSON over stdout.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --interval 2.0 --sensitivity 0.6
  %(prog)s --camera 1 --verbose
        """,
    )
    parser.add_argument(
        "--interval",
        "-i",
        type=float,
        default=10.0,
        metavar="SECONDS",
        help="Time between posture checks (default: 10.0 seconds)",
    )
    parser.add_argument(
        "--camera", "-c", type=int, default=0, metavar="INDEX", help="Camera device index (default: 0)"
    )
    parser.add_argument(
        "--sensitivity",
        "-s",
        type=float,
        default=0.4,
        metavar="FLOAT",
        help="Posture detection sensitivity 0.0-1.0 (default: 0.4)",
    )
    parser.add_argument("--verbose", "-v", action="store_true", help="Enable verbose logging to stderr")

    args = parser.parse_args()

    # Validate arguments
    if args.interval <= 0:
        parser.error("--interval must be positive")
    if args.camera < 0:
        parser.error("--camera must be non-negative")
    if not (0.0 <= args.sensitivity <= 1.0):
        parser.error("--sensitivity must be between 0.0 and 1.0")

    return args


def main() -> int:
    """
    Main entry point for the CLI application.

    Returns:
        int: Exit code (0 for success, non-zero for error)
    """
    args = parse_args()
    cli = PostureStreamCLI(
        interval=args.interval,
        camera_index=args.camera,
        sensitivity=args.sensitivity,
        verbose=args.verbose,
    )
    return cli.run()


if __name__ == "__main__":
    sys.exit(main())
