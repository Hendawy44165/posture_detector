import 'dart:async';

import 'package:posture_detector/models/posture_models.dart';
import 'package:posture_detector/services/background_process_service.dart';
import 'package:posture_detector/components/enums/posture_state.dart';
import 'package:posture_detector/services/notification_service.dart';
import 'package:posture_detector/components/enums/error_messages.dart';
import 'package:posture_detector/services/sound_pref_service.dart';
import 'package:riverpod/riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/services.dart';

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
  int _leaningCounter = 0;
  int _postureErrorCounter = 0;
  int _sittingTooLongCounter = 0;
  SoundPrefService? _soundPrefService;
  bool _soundEnabled = true;

  PostureMonitorNotifier() : super(PostureMonitorState()) {
    _initSoundPref();
  }

  bool get soundEnabled => _soundEnabled;
  PostureMonitorClient? _client;
  StreamSubscription<PostureResult>? _postureSubscription;
  StreamSubscription<PostureError>? _errorSubscription;

  void toggleSound(bool value) {
    _soundEnabled = value;
    _soundPrefService?.setSoundEnabled(value);
  }

  Future<void> startMonitoring() async {
    if (state.isMonitoring) return;

    try {
      final config = PostureMonitorConfig(
        sensitivity: state.sensitivity,
        interval: 1.0,
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

      await _client!.start();
      state = state.copyWith(isMonitoring: true, errorMessage: null);
    } catch (e) {
      state = state.copyWith(
        postureState: PostureState.notResolved,
        isMonitoring: false,
        errorMessage: 'Failed to start monitoring: $e',
      );
    }
  }

  Future<void> stopMonitoring() async {
    await _postureSubscription?.cancel();
    await _errorSubscription?.cancel();
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
      startMonitoring();
    }
  }

  void clearErrorState() {
    state = state.copyWith(errorMessage: null);
  }

  void _handlePostureResult(PostureResult result) async {
    _sittingTooLongCounter++;
    if (_sittingTooLongCounter > 1800) {
      NotificationService().show(
        'THE EGGS HATCHED !!',
        'You have been sitting for too long',
      );
      unawaited(windowManager.setAlwaysOnTop(true));
      unawaited(windowManager.focus());
      unawaited(windowManager.restore());
      unawaited(windowManager.setAlwaysOnTop(false));
      if (_soundEnabled) {
        await SystemSound.play(SystemSoundType.alert);
      }
      _sittingTooLongCounter = 0;
    }
    final newPostureState = result.isLeaning
        ? PostureState.leaning
        : PostureState.upright;

    if (result.isLeaning) {
      _leaningCounter++;
      if (_leaningCounter > 10) {
        unawaited(windowManager.setAlwaysOnTop(true));
        unawaited(windowManager.focus());
        unawaited(windowManager.restore());
        unawaited(windowManager.setAlwaysOnTop(false));
        _leaningCounter = 0;
        if (_soundEnabled) {
          await SystemSound.play(SystemSoundType.alert);
        }
      }
    } else {
      _leaningCounter = 0;
    }

    if (state.postureState == newPostureState)
      return; // prevent unnecessary state updates

    state = state.copyWith(postureState: newPostureState, errorMessage: null);
  }

  void _handlePostureError(PostureError error) async {
    _postureErrorCounter++;
    if (_postureErrorCounter < 5) return;
    if (state.postureState == PostureState.notResolved) return;

    _sittingTooLongCounter = 0;
    final userMessage = error.message.userFriendly;
    NotificationService().show('Posture Detector', userMessage);
    if (_soundEnabled) {
      await SystemSound.play(SystemSoundType.alert);
    }
    state = state.copyWith(
      postureState: PostureState.notResolved,
      errorMessage: 'Detection error: $userMessage',
    );
    _postureErrorCounter = 0;
  }

  void _handleStreamError(dynamic error) async {
    if (state.postureState == PostureState.notResolved) return;

    final userMessage = error.toString().userFriendly;
    NotificationService().show('Posture Detector', userMessage);
    if (_soundEnabled) {
      await SystemSound.play(SystemSoundType.alert);
    }
    state = state.copyWith(
      postureState: PostureState.notResolved,
      errorMessage: 'Stream error: $userMessage',
    );
  }

  Future<void> _initSoundPref() async {
    _soundPrefService = await SoundPrefService.getInstance();
    _soundEnabled = _soundPrefService?.soundEnabled ?? true;
    state = state.copyWith();
  }

  @override
  void dispose() {
    _postureSubscription?.cancel();
    _errorSubscription?.cancel();
    _client?.dispose();
    super.dispose();
  }
}

StateNotifierProvider<PostureMonitorNotifier, PostureMonitorState>
getPostureMonitorProvider() =>
    StateNotifierProvider<PostureMonitorNotifier, PostureMonitorState>(
      (ref) => PostureMonitorNotifier(),
    );
