import 'package:posture_detector/models/posture_models.dart';
import 'package:posture_detector/services/background_process_service.dart';
import 'package:posture_detector/components/enums/posture_state.dart';
import 'package:flutter/material.dart';
import 'package:riverpod/riverpod.dart';
import 'dart:async';

class PostureMonitorState {
  final PostureState postureState;
  final bool isMonitoring;
  final double sensitivity;
  final String? errorMessage;

  PostureMonitorState({
    this.postureState = PostureState.notResolved,
    this.isMonitoring = false,
    this.sensitivity = 0.4,
    this.errorMessage,
  });

  PostureMonitorState copyWith({
    PostureState? postureState,
    bool? isMonitoring,
    double? sensitivity,
    String? errorMessage,
  }) {
    return PostureMonitorState(
      postureState: postureState ?? this.postureState,
      isMonitoring: isMonitoring ?? this.isMonitoring,
      sensitivity: sensitivity ?? this.sensitivity,
      errorMessage: errorMessage,
    );
  }
}

class PostureMonitorNotifier extends StateNotifier<PostureMonitorState> {
  PostureMonitorClient? _client;
  StreamSubscription<PostureResult>? _postureSubscription;
  StreamSubscription<PostureError>? _errorSubscription;
  StreamSubscription<PostureStatus>? _statusSubscription;

  PostureMonitorNotifier() : super(PostureMonitorState());

  Future<void> startMonitoring() async {
    if (state.isMonitoring) return;

    try {
      final config = PostureMonitorConfig(
        sensitivity: state.sensitivity,
        interval: 1.0,
        verbose: true,
      );

      _client = PostureMonitorClient(config: config);

      _postureSubscription = _client!.postureStream.listen(
        _handlePostureResult,
        onError: _handleStreamError,
      );

      _errorSubscription = _client!.errorStream.listen(
        _handlePostureError,
        onError: _handleStreamError,
      );

      _statusSubscription = _client!.statusStream.listen(
        _handleStatusUpdate,
        onError: _handleStreamError,
      );

      await _client!.start();
      state = state.copyWith(isMonitoring: true, errorMessage: null);
    } catch (e) {
      state = state.copyWith(
        postureState: PostureState.notResolved,
        isMonitoring: false,
        errorMessage: 'Failed to start monitoring: $e',
      );
      debugPrint('Monitoring error: $e');
    }
  }

  Future<void> stopMonitoring() async {
    await _postureSubscription?.cancel();
    await _errorSubscription?.cancel();
    await _statusSubscription?.cancel();
    await _client?.stop();

    state = state.copyWith(
      isMonitoring: false,
      postureState: PostureState.notResolved,
      errorMessage: null,
    );
  }

  void updateSensitivity(double value) {
    state = state.copyWith(sensitivity: value);
    if (state.isMonitoring) {
      stopMonitoring();
    }
  }

  void clearErrorState() {
    state = state.copyWith(errorMessage: null);
  }

  void _handlePostureResult(PostureResult result) {
    state = state.copyWith(
      postureState: result.isLeaning
          ? PostureState.leaning
          : PostureState.upright,
      errorMessage: null,
    );
  }

  void _handlePostureError(PostureError error) {
    state = state.copyWith(
      postureState: PostureState.notResolved,
      errorMessage: 'Detection error: ${error.message}',
    );
  }

  void _handleStatusUpdate(PostureStatus status) {
    debugPrint('Status: ${status.message}');
  }

  void _handleStreamError(dynamic error) {
    state = state.copyWith(
      postureState: PostureState.notResolved,
      errorMessage: 'Stream error: $error',
    );
  }

  @override
  void dispose() {
    _postureSubscription?.cancel();
    _errorSubscription?.cancel();
    _statusSubscription?.cancel();
    _client?.dispose();
    super.dispose();
  }
}

final postureMonitorProvider =
    StateNotifierProvider<PostureMonitorNotifier, PostureMonitorState>(
      (ref) => PostureMonitorNotifier(),
    );
