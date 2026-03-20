import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../services/audio_bridge.dart';
import '../services/note_utils.dart';

/// Notation style for note names.
enum NotationStyle {
  scientific,
  helmholtz,
}

enum TunerStartupState {
  initializing,
  ready,
  microphonePermissionDenied,
  nativeUnavailable,
}

/// Application-wide state for the tuner, exposed via [ChangeNotifier].
class TunerModel extends ChangeNotifier {
  TunerModel() {
    _bootstrap();
  }

  final AudioBridge _bridge = AudioBridge();

  // ---- Settings ----
  double _a4Frequency = 440.0;
  NotationStyle _notationStyle = NotationStyle.scientific;

  // ---- Live tuner data ----
  double _frequency = 0.0;
  double _cents = 0.0;
  int _midiNote = -1;
  double _confidence = 0.0;
  TunerStartupState _startupState = TunerStartupState.initializing;
  String _statusMessage = '正在启动音频引擎…';
  bool _isBootstrapping = false;

  static const int waveformLength = 1024;
  final Float32List _displayWaveform = Float32List(waveformLength);
  final Float32List _scratchWaveform = Float32List(waveformLength);
  int _frozenMidiNote = -1;

  // ---- Getters ----
  double get a4Frequency => _a4Frequency;
  NotationStyle get notationStyle => _notationStyle;
  double get frequency => _frequency;
  double get cents => _cents;
  int get midiNote => _midiNote;
  double get confidence => _confidence;
  Float32List get waveform => _displayWaveform;
  TunerStartupState get startupState => _startupState;
  String get statusMessage => _statusMessage;
  bool get isReady => _startupState == TunerStartupState.ready;
  bool get isInitializing => _startupState == TunerStartupState.initializing;

  bool get isDetected => _confidence > 0.4 && _frequency > 0;

  String get noteName {
    if (_frozenMidiNote < 0) return '--';
    return NoteUtils.noteName(
      _frozenMidiNote,
      useHelmholtz: _notationStyle == NotationStyle.helmholtz,
    );
  }

  String get frequencyLabel {
    if (!isDetected) return '---.-';
    return '${_frequency.toStringAsFixed(1)} Hz';
  }

  String get centsLabel {
    if (!isDetected) return '';
    final sign = _cents >= 0 ? '+' : '';
    return '$sign${_cents.toStringAsFixed(1)}¢';
  }

  // ---- Setters ----
  void setA4Frequency(double freq) {
    _a4Frequency = freq.clamp(420.0, 460.0);
    _bridge.setA4Frequency(_a4Frequency);
    notifyListeners();
  }

  void setNotationStyle(NotationStyle style) {
    _notationStyle = style;
    notifyListeners();
  }

  Future<void> retryInitialization() async {
    await _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (_isBootstrapping) return;

    _isBootstrapping = true;
    _startupState = TunerStartupState.initializing;
    _statusMessage = '正在请求麦克风权限并启动音频引擎…';
    notifyListeners();

    final result = await _bridge.initialize();
    switch (result.status) {
      case AudioBridgeInitStatus.ready:
        _bridge.setNoiseFloor(-55.0);
        _bridge.start();
        _startupState = TunerStartupState.ready;
        _statusMessage = '';
      case AudioBridgeInitStatus.microphonePermissionDenied:
        _startupState = TunerStartupState.microphonePermissionDenied;
        _statusMessage = '未获得麦克风权限。请在系统设置中允许此应用访问麦克风。';
      case AudioBridgeInitStatus.nativeLibraryUnavailable:
        _startupState = TunerStartupState.nativeUnavailable;
        _statusMessage = result.message ?? '原生音频库未加载，当前不会显示伪造的波形或音高数据。';
    }

    _isBootstrapping = false;
    notifyListeners();
  }

  /// Called periodically (e.g. from a [Timer]) to pull the latest data from
  /// the native library and notify listeners.
  void tick() {
    if (!isReady) return;

    _frequency = _bridge.getFrequency();
    _cents = _bridge.getCents();
    _midiNote = _bridge.getMidiNote();
    _confidence = _bridge.getConfidence();

    if (!isDetected) {
      notifyListeners();
      return;
    }

    final n = _bridge.getWaveform(_scratchWaveform);
    if (n > 0) {
      _displayWaveform.setAll(0, _scratchWaveform);
    }
    if (n > 0 && n < waveformLength) {
      // Zero-pad if fewer samples are available
      for (int i = n; i < waveformLength; i++) {
        _displayWaveform[i] = 0.0;
      }
    }
    _frozenMidiNote = _midiNote;

    notifyListeners();
  }

  @override
  void dispose() {
    _bridge.stop();
    _bridge.dispose();
    super.dispose();
  }
}
