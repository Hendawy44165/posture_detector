"""
posture_detector.py
------------------
This module provides the PostureDetector class, which uses OpenCV and MediaPipe to detect whether a person is sitting upright or leaning forward in an image frame.

Classes:
    PostureDetector: Detects posture state (upright or leaning forward) from a camera frame.

Usage Example:
    detector = PostureDetector(sensitivity=0.4)
    is_leaning = detector.is_leaning_forward(frame)
    # is_leaning is True if leaning forward, False if upright
"""

import cv2
import mediapipe as mp
from cv2.typing import MatLike


class PostureDetector:
    def __init__(self, sensitivity=0.4):
        """
        Initialize the PostureDetector.

        Args:
            sensitivity (float): Sensitivity for posture detection (default is 0.4).
        """
        # Initialize MediaPipe solutions
        self.mp_pose = mp.solutions.pose
        self.mp_face_mesh = mp.solutions.face_mesh
        self.mp_drawing = mp.solutions.drawing_utils
        self.mp_drawing_styles = mp.solutions.drawing_styles
        self.sensitivity = sensitivity * 0.4

        # Initialize pose and face mesh
        self.pose = self.mp_pose.Pose(
            static_image_mode=False,
            model_complexity=2,
            enable_segmentation=False,
            min_detection_confidence=0.5,
            min_tracking_confidence=0.5,
        )

        self.face_mesh = self.mp_face_mesh.FaceMesh(
            static_image_mode=False,
            max_num_faces=1,
            refine_landmarks=True,
            min_detection_confidence=0.5,
            min_tracking_confidence=0.5,
        )

        # Chin landmark index in MediaPipe face mesh (bottom of chin)
        self.CHIN_INDEX = 175

    def is_leaning_forward(self, cv_frame: MatLike):
        """
        Check if the person in the frame is leaning forward by comparing chin and shoulder heights.

        Args:
            cv_frame (MatLike): The image frame (BGR) from the camera.

        Returns:
            bool: True if leaning forward, False if upright.

        Raises:
            RuntimeError: If chin or shoulder position cannot be detected.
        """
        image_rgb = cv2.cvtColor(cv_frame, cv2.COLOR_BGR2RGB)
        image_shape = cv_frame.shape

        pose_results = self.pose.process(image_rgb)
        face_results = self.face_mesh.process(image_rgb)

        chin_pos = None
        if face_results.multi_face_landmarks:
            chin_pos = self._get_chin_position(face_results.multi_face_landmarks[0], image_shape)

        shoulder_pos = None
        if pose_results.pose_landmarks:
            shoulder_pos = self._get_shoulder_positions(pose_results.pose_landmarks, image_shape)

        if chin_pos and shoulder_pos:
            chin_y = chin_pos[1]
            shoulder_y = shoulder_pos[1]
            if chin_y > shoulder_y:
                return True
            return False
        return None

    def _get_chin_position(self, face_landmarks, image_shape):
        """
        Extract chin position from face landmarks.

        Args:
            face_landmarks: The face landmarks object from MediaPipe.
            image_shape (tuple): Shape of the image (height, width, channels).

        Returns:
            tuple: (x, y) coordinates of the chin.

        Raises:
            RuntimeError: If no face landmarks are detected.
        """
        if face_landmarks:
            chin_landmark = face_landmarks.landmark[self.CHIN_INDEX]
            chin_x = int(chin_landmark.x * image_shape[1])
            chin_y = int(chin_landmark.y * image_shape[0])
            return chin_x, chin_y
        raise RuntimeError("No face landmarks detected for chin position.")

    def _get_shoulder_positions(self, pose_landmarks, image_shape):
        """
        Extract the uppermost shoulder position from pose landmarks.

        Args:
            pose_landmarks: The pose landmarks object from MediaPipe.
            image_shape (tuple): Shape of the image (height, width, channels).

        Returns:
            tuple: (x, y) coordinates of the uppermost shoulder.

        Raises:
            RuntimeError: If no pose landmarks are detected.
        """
        if pose_landmarks:
            left_shoulder = pose_landmarks.landmark[self.mp_pose.PoseLandmark.LEFT_SHOULDER]
            right_shoulder = pose_landmarks.landmark[self.mp_pose.PoseLandmark.RIGHT_SHOULDER]
            left_ear = pose_landmarks.landmark[self.mp_pose.PoseLandmark.LEFT_EAR]
            right_ear = pose_landmarks.landmark[self.mp_pose.PoseLandmark.RIGHT_EAR]
            left_upper_shoulder_x = int(left_shoulder.x * image_shape[1])
            left_upper_shoulder_y = int(
                (self.sensitivity * (left_ear.y - left_shoulder.y) + left_shoulder.y) * image_shape[0]
            )
            right_upper_shoulder_x = int(right_shoulder.x * image_shape[1])
            right_upper_shoulder_y = int(
                (self.sensitivity * (right_ear.y - right_shoulder.y) + right_shoulder.y) * image_shape[0]
            )
            if left_upper_shoulder_y < right_upper_shoulder_y:
                return left_upper_shoulder_x, left_upper_shoulder_y
            else:
                return right_upper_shoulder_x, right_upper_shoulder_y
        raise RuntimeError("No pose landmarks detected for shoulder position.")
