"""
camera_monitor.py
-----------------
This module provides the CameraMonitor class, which periodically captures images from a camera,
uses PostureDetector to analyze posture, and streams the posture state (leaning or upright) to subscribers.

Classes:
    CameraMonitor: Streams posture state from camera frames at regular intervals.

Usage Example:
    from camera_monitor import CameraMonitor
    monitor = CameraMonitor(interval=2.0)
    stream = monitor.subscribe()
    try:
        for is_leaning in stream:
            print('Leaning' if is_leaning else 'Upright')
    except RuntimeError as e:
        print(f"Camera error: {e}")
"""

import cv2
import time
from threading import Lock
from posture_detector import PostureDetector


class CameraMonitor:
    """
    Monitors posture by capturing images from the camera at regular intervals
    and yielding the leaning state (True/False) as a stream.
    """

    def __init__(self, interval=10.0, camera_index=0, sensitivity=0.4):
        """
        Initialize the CameraMonitor.

        Args:
            interval (float): Time between captures in seconds.
            camera_index (int): Index of the camera to use (default is 0 for built-in webcam).
            sensitivity (float): Sensitivity for posture detection (default is 0.4).
        """
        self.interval = interval
        self.camera_index = camera_index
        self.detector = PostureDetector(sensitivity=sensitivity)
        self._subscribers = set()
        self._lock = Lock()
        self._active = False

    def subscribe(self, subscriber_id=None):
        """
        Subscribe to the posture stream.

        Args:
            subscriber_id (Any, optional): Unique identifier for the subscriber. If not provided, uses the object's id.

        Returns:
            generator: A generator that yields posture states (True for leaning, False for upright).
        """
        with self._lock:
            sid = subscriber_id or id(self)
            self._subscribers.add(sid)
            self._active = True
        return self._posture_stream(sid)

    def unsubscribe(self, subscriber_id=None):
        """
        Unsubscribe from the posture stream.

        Args:
            subscriber_id (Any, optional): The subscriber ID to remove. If not provided, removes all subscribers.
        """
        with self._lock:
            if subscriber_id:
                self._subscribers.discard(subscriber_id)
            else:
                self._subscribers.clear()
            if not self._subscribers:
                self._active = False

    def _posture_stream(self, sid):
        """
        Generator that yields posture state every interval seconds until unsubscribed.

        Args:
            sid (Any): The subscriber ID for this stream.

        Yields:
            bool: True if leaning forward, False if upright.

        Raises:
            RuntimeError: If the camera cannot be opened or a frame cannot be captured.
        """
        while True:
            with self._lock:
                if sid not in self._subscribers:
                    break
            cap = cv2.VideoCapture(self.camera_index)
            try:
                if not cap.isOpened():
                    raise RuntimeError("Could not open camera.")
                ret, frame = cap.read()
                if not ret:
                    raise RuntimeError("Failed to capture image from camera.")
                is_leaning = self.detector.is_leaning_forward(frame)
                yield is_leaning
            finally:
                cap.release()
            time.sleep(self.interval)


if __name__ == "__main__":
    camera_monitor = CameraMonitor(interval=2.0, camera_index=0, sensitivity=0.4)

    try:
        for posture in camera_monitor.subscribe():
            print("Posture leaning forward:", posture)
    except KeyboardInterrupt:
        print("Stopping camera monitor.")
    finally:
        camera_monitor.unsubscribe()
