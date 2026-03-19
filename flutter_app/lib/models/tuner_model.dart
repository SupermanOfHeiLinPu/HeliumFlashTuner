import 'dart:typed_data';
import 'package:flutter/foundation.dart';

import '../services/audio_bridge.dart';
import '../services/note_utils.dart';

/// Notation style for note names.
enum NotationStyle {
  scientific,
  helmholtz,
}

/// Application-wide state for the tuner, exposed via [ChangeNotifier].
class TunerModel extends ChangeNotifier {
  TunerModel() {
    _bridge.initialize();
    _bridge.start();
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

  static const int waveformLength = 1024;
  final Float32List _waveform = Float32List(waveformLength);

  // ---- Getters ----
  double get a4Frequency => _a4Frequency;
  NotationStyle get notationStyle => _notationStyle;
  double get frequency => _frequency;
  double get cents => _cents;
  int get midiNote => _midiNote;
  double get confidence => _confidence;
  Float32List get waveform => _waveform;

  bool get isDetected => _confidence > 0.4 && _frequency > 0;

  String get noteName {
    if (!isDetected) return '--';
    return NoteUtils.noteName(
      _midiNote,
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

  /// Called periodically (e.g. from a [Timer]) to pull the latest data from
  /// the native library and notify listeners.
  void tick() {
    _frequency = _bridge.getFrequency();
    _cents = _bridge.getCents();
    _midiNote = _bridge.getMidiNote();
    _confidence = _bridge.getConfidence();

    final n = _bridge.getWaveform(_waveform);
    if (n < waveformLength) {
      // Zero-pad if fewer samples are available
      for (int i = n; i < waveformLength; i++) {
        _waveform[i] = 0.0;
      }
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _bridge.stop();
    _bridge.dispose();
    super.dispose();
  }
}
