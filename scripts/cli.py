"""
cli.py
------
Command-line interface for CameraMonitor that streams posture detection results
over stdio protocol with robust error handling and buffering management.

This CLI provides:
- JSON-formatted output for structured data exchange
- Configurable monitoring parameters via command-line arguments
- Graceful shutdown handling
- Proper stdout flushing to prevent buffering issues
- Comprehensive error reporting to stderr
- Production-ready logging and monitoring

Usage:
    python cli.py [options]

Examples:
    python cli.py --interval 2.0 --sensitivity 0.4
    python cli.py --camera 1 --format json --verbose
"""

import os
import sys
import json
import time
import signal
import argparse
import logging
from typing import Optional, Dict, Any
from contextlib import contextmanager

from camera_monitor import CameraMonitor

# Check and activate venv, install requirements if needed
venv_dir = os.path.join(os.path.dirname(__file__), "venv")
requirements = os.path.join(os.path.dirname(__file__), "requirements.txt")
if not os.path.exists(venv_dir):
    import subprocess

    print("Setting up virtual environment...", file=sys.stderr)
    subprocess.check_call([sys.executable, "venv_setup.py"])
venv_python = (
    os.path.join(venv_dir, "bin", "python")
    if os.name != "nt"
    else os.path.join(venv_dir, "Scripts", "python.exe")
)
if sys.executable != venv_python:
    os.execv(venv_python, [venv_python] + sys.argv)


class PostureStreamCLI:
    """
    Command-line interface for streaming posture detection results over stdio.

    Handles JSON formatting, error management, and graceful shutdown.
    """

    def __init__(
        self,
        interval: float = 1.0,
        camera_index: int = 0,
        sensitivity: float = 0.4,
        output_format: str = "json",
        verbose: bool = False,
    ):
        """
        Initialize the CLI with monitoring parameters.

        Args:
            interval: Time between captures in seconds
            camera_index: Camera device index
            sensitivity: Posture detection sensitivity (0.0-1.0)
            output_format: Output format ('json' or 'text')
            verbose: Enable verbose logging to stderr
        """
        self.monitor = CameraMonitor(interval=interval, camera_index=camera_index, sensitivity=sensitivity)
        self.output_format = output_format
        self.verbose = verbose
        self.running = True
        self.subscriber_id = id(self)

        # Configure logging to stderr only
        self._setup_logging()

        # Register signal handlers for graceful shutdown
        signal.signal(signal.SIGINT, self._signal_handler)
        signal.signal(signal.SIGTERM, self._signal_handler)

    def _setup_logging(self):
        """Configure logging to stderr with appropriate level."""
        level = logging.DEBUG if self.verbose else logging.WARNING
        logging.basicConfig(
            level=level,
            format="%(asctime)s - %(levelname)s - %(message)s",
            stream=sys.stderr,
            force=True,
        )
        self.logger = logging.getLogger(__name__)

    def _signal_handler(self, signum: int):
        """Handle shutdown signals gracefully."""
        self.logger.info(f"Received signal {signum}, initiating shutdown...")
        self.running = False

    @contextmanager
    def _error_context(self, operation: str):
        """
        Context manager for consistent error handling and reporting.

        Args:
            operation: Description of the operation being performed
        """
        try:
            yield
        except KeyboardInterrupt:
            self.logger.info("Received keyboard interrupt")
            self.running = False
        except Exception as e:
            error_msg = f"Error during {operation}: {str(e)}"
            self.logger.error(error_msg)
            self._output_error(error_msg)
            raise

    def _output_error(self, message: str):
        """
        Output error message in the appropriate format.

        Args:
            message: Error message to output
        """
        if self.output_format == "json":
            error_data = {"timestamp": time.time(), "type": "error", "message": message}
            self._write_json(error_data)
        else:
            self._write_text(f"ERROR: {message}")

    def _output_posture(self, is_leaning: bool, timestamp: float):
        """
        Output posture data in the specified format.

        Args:
            is_leaning: Whether the person is leaning forward
            timestamp: Unix timestamp of the measurement
        """
        if self.output_format == "json":
            data = {
                "timestamp": timestamp,
                "type": "posture",
                "is_leaning": is_leaning,
                "posture": "leaning" if is_leaning else "upright",
            }
            self._write_json(data)
        else:
            posture_str = "leaning" if is_leaning else "upright"
            self._write_text(f"{timestamp:.3f}: {posture_str}")

    def _write_json(self, data: Dict[str, Any]):
        """
        Write JSON data to stdout with proper flushing.

        Args:
            data: Dictionary to serialize as JSON
        """
        try:
            json_str = json.dumps(data, separators=(",", ":"))
            sys.stdout.write(json_str + "\n")
            sys.stdout.flush()
        except (IOError, OSError) as e:
            self.logger.error(f"Failed to write JSON output: {e}")
            self.running = False

    def _write_text(self, message: str):
        """
        Write text message to stdout with proper flushing.

        Args:
            message: Text message to output
        """
        try:
            sys.stdout.write(message + "\n")
            sys.stdout.flush()
        except (IOError, OSError) as e:
            self.logger.error(f"Failed to write text output: {e}")
            self.running = False

    def _output_status(self, message: str):
        """
        Output status message in appropriate format.

        Args:
            message: Status message
        """
        if self.output_format == "json":
            status_data = {"timestamp": time.time(), "type": "status", "message": message}
            self._write_json(status_data)
        else:
            self._write_text(f"STATUS: {message}")

    def run(self):
        """
        Main execution loop that streams posture detection results.

        Returns:
            int: Exit code (0 for success, 1 for error)
        """
        try:
            self.logger.info("Starting posture monitoring...")
            self._output_status("Starting posture monitoring")

            with self._error_context("camera monitor subscription"):
                stream = self.monitor.subscribe(self.subscriber_id)

            self.logger.info("Successfully subscribed to camera monitor")
            self._output_status("Camera monitor active")

            # Main monitoring loop
            for is_leaning in stream:
                if not self.running:
                    break

                timestamp = time.time()

                with self._error_context("posture output"):
                    self._output_posture(is_leaning, timestamp)

                self.logger.debug(f"Posture detected: {'leaning' if is_leaning else 'upright'}")

            return 0

        except RuntimeError as e:
            error_msg = f"Camera error: {str(e)}"
            self.logger.error(error_msg)
            self._output_error(error_msg)
            return 1

        except Exception as e:
            error_msg = f"Unexpected error: {str(e)}"
            self.logger.error(error_msg, exc_info=True)
            self._output_error(error_msg)
            return 1

        finally:
            self._cleanup()

    def _cleanup(self):
        """Perform cleanup operations."""
        try:
            self.monitor.unsubscribe(self.subscriber_id)
            self.logger.info("Unsubscribed from camera monitor")
            self._output_status("Posture monitoring stopped")
        except Exception as e:
            self.logger.error(f"Error during cleanup: {e}")


def create_argument_parser() -> argparse.ArgumentParser:
    """
    Create and configure the command-line argument parser.

    Returns:
        argparse.ArgumentParser: Configured argument parser
    """
    parser = argparse.ArgumentParser(
        description="Stream posture detection results over stdio",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s                              # Use default settings
  %(prog)s --interval 2.0 --sensitivity 0.6
  %(prog)s --camera 1 --format text --verbose
  %(prog)s --help                       # Show this help message

Output Formats:
  json: Structured JSON output (default)
  text: Human-readable text output

The program outputs posture data to stdout and logs to stderr.
Use Ctrl+C or send SIGTERM for graceful shutdown.
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

    parser.add_argument(
        "--format", "-f", choices=["json", "text"], default="json", help="Output format (default: json)"
    )

    parser.add_argument("--verbose", "-v", action="store_true", help="Enable verbose logging to stderr")

    return parser


def validate_arguments(args: argparse.Namespace) -> Optional[str]:
    """
    Validate command-line arguments.

    Args:
        args: Parsed command-line arguments

    Returns:
        str or None: Error message if validation fails, None if valid
    """
    if args.interval <= 0:
        return "Interval must be positive"

    if args.camera < 0:
        return "Camera index must be non-negative"

    if not (0.0 <= args.sensitivity <= 1.0):
        return "Sensitivity must be between 0.0 and 1.0"

    return None


def main() -> int:
    """
    Main entry point for the CLI application.

    Returns:
        int: Exit code (0 for success, non-zero for error)
    """
    parser = create_argument_parser()
    args = parser.parse_args()

    # Validate arguments
    validation_error = validate_arguments(args)
    if validation_error:
        print(f"Error: {validation_error}", file=sys.stderr)
        parser.print_help(sys.stderr)
        return 1

    # Create and run the CLI
    cli = PostureStreamCLI(
        interval=args.interval,
        camera_index=args.camera,
        sensitivity=args.sensitivity,
        output_format=args.format,
        verbose=args.verbose,
    )

    return cli.run()


if __name__ == "__main__":
    sys.exit(main())
