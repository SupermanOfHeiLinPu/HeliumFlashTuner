import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

// ---------------------------------------------------------------------------
// Native function type definitions
// ---------------------------------------------------------------------------

typedef _TunerInitNative = Void Function(Int32 sampleRate);
typedef _TunerInit = void Function(int sampleRate);

typedef _TunerStartNative = Void Function();
typedef _TunerStart = void Function();

typedef _TunerStopNative = Void Function();
typedef _TunerStop = void Function();

typedef _TunerCleanupNative = Void Function();
typedef _TunerCleanup = void Function();

typedef _TunerSetA4Native = Void Function(Double freq);
typedef _TunerSetA4 = void Function(double freq);

typedef _TunerGetA4Native = Double Function();
typedef _TunerGetA4 = double Function();

typedef _TunerGetFrequencyNative = Double Function();
typedef _TunerGetFrequency = double Function();

typedef _TunerGetCentsNative = Double Function();
typedef _TunerGetCents = double Function();

typedef _TunerGetMidiNoteNative = Int32 Function();
typedef _TunerGetMidiNote = int Function();

typedef _TunerGetConfidenceNative = Double Function();
typedef _TunerGetConfidence = double Function();

typedef _TunerSetNoiseFloorNative = Void Function(Double db);
typedef _TunerSetNoiseFloor = void Function(double db);

typedef _TunerGetWaveformNative = Int32 Function(
    Pointer<Float> buffer, Int32 maxSamples);
typedef _TunerGetWaveform = int Function(
    Pointer<Float> buffer, int maxSamples);

// ---------------------------------------------------------------------------

/// Bridge between the Flutter UI and the native JUCE audio library.
///
/// The native library exposes a C API (see `native/Source/TunerBridge.h`)
/// that is loaded via [dart:ffi].  When no native library is present (e.g.
/// during unit tests or on unsupported platforms) the bridge operates in
/// *stub mode* and returns synthesised demo values.
class AudioBridge {
  static AudioBridge? _instance;
  factory AudioBridge() => _instance ??= AudioBridge._();
  AudioBridge._();

  DynamicLibrary? _lib;
  bool _stubMode = false;

  // Bound native functions
  late _TunerInit _init;
  late _TunerStart _start;
  late _TunerStop _stop;
  late _TunerCleanup _cleanup;
  late _TunerSetA4 _setA4;
  late _TunerGetA4 _getA4;
  late _TunerGetFrequency _getFrequency;
  late _TunerGetCents _getCents;
  late _TunerGetMidiNote _getMidiNote;
  late _TunerGetConfidence _getConfidence;
  late _TunerSetNoiseFloor _setNoiseFloor;
  late _TunerGetWaveform _getWaveform;

  // Stub state for demo / unit tests
  double _stubA4 = 440.0;
  int _stubTick = 0;

  /// Initialises the bridge.  Must be called once before any other method.
  void initialize({int sampleRate = 44100}) {
    try {
      _lib = _loadLibrary();
      _bindFunctions();
      _init(sampleRate);
    } catch (_) {
      // Fall back to stub mode when the native library is unavailable.
      _stubMode = true;
    }
  }

  void start() {
    if (_stubMode) return;
    _start();
  }

  void stop() {
    if (_stubMode) return;
    _stop();
  }

  void dispose() {
    if (_stubMode) return;
    _cleanup();
  }

  void setA4Frequency(double freq) {
    if (_stubMode) {
      _stubA4 = freq;
      return;
    }
    _setA4(freq);
  }

  double getA4Frequency() {
    if (_stubMode) return _stubA4;
    return _getA4();
  }

  double getFrequency() {
    if (_stubMode) return _demoFrequency();
    return _getFrequency();
  }

  double getCents() {
    if (_stubMode) return _demoCents();
    return _getCents();
  }

  int getMidiNote() {
    if (_stubMode) return 69; // A4
    return _getMidiNote();
  }

  double getConfidence() {
    if (_stubMode) return 0.9;
    return _getConfidence();
  }

  void setNoiseFloor(double db) {
    if (_stubMode) return;
    _setNoiseFloor(db);
  }

  /// Fills [outBuffer] with the most recent waveform samples.
  /// Returns the number of samples actually written.
  int getWaveform(Float32List outBuffer) {
    if (_stubMode) {
      return _demoWaveform(outBuffer);
    }
    final ptr =
        malloc.allocate<Float>(sizeOf<Float>() * outBuffer.length);
    try {
      final n = _getWaveform(ptr, outBuffer.length);
      for (int i = 0; i < n; i++) {
        outBuffer[i] = ptr[i];
      }
      return n;
    } finally {
      malloc.free(ptr);
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  static DynamicLibrary _loadLibrary() {
    const libName = 'helium_flash_tuner';
    if (Platform.isAndroid || Platform.isLinux) {
      return DynamicLibrary.open('lib$libName.so');
    }
    if (Platform.isMacOS) {
      return DynamicLibrary.open('lib$libName.dylib');
    }
    if (Platform.isWindows) {
      return DynamicLibrary.open('$libName.dll');
    }
    throw UnsupportedError(
        'Unsupported platform: ${Platform.operatingSystem}');
  }

  void _bindFunctions() {
    final lib = _lib!;
    _init =
        lib.lookupFunction<_TunerInitNative, _TunerInit>('tuner_init');
    _start =
        lib.lookupFunction<_TunerStartNative, _TunerStart>('tuner_start');
    _stop =
        lib.lookupFunction<_TunerStopNative, _TunerStop>('tuner_stop');
    _cleanup =
        lib.lookupFunction<_TunerCleanupNative, _TunerCleanup>('tuner_cleanup');
    _setA4 = lib.lookupFunction<_TunerSetA4Native, _TunerSetA4>(
        'tuner_set_a4_frequency');
    _getA4 = lib.lookupFunction<_TunerGetA4Native, _TunerGetA4>(
        'tuner_get_a4_frequency');
    _getFrequency =
        lib.lookupFunction<_TunerGetFrequencyNative, _TunerGetFrequency>(
            'tuner_get_frequency');
    _getCents =
        lib.lookupFunction<_TunerGetCentsNative, _TunerGetCents>(
            'tuner_get_cents');
    _getMidiNote =
        lib.lookupFunction<_TunerGetMidiNoteNative, _TunerGetMidiNote>(
            'tuner_get_midi_note');
    _getConfidence =
        lib.lookupFunction<_TunerGetConfidenceNative, _TunerGetConfidence>(
            'tuner_get_confidence');
    _setNoiseFloor =
        lib.lookupFunction<_TunerSetNoiseFloorNative, _TunerSetNoiseFloor>(
            'tuner_set_noise_floor');
    _getWaveform =
        lib.lookupFunction<_TunerGetWaveformNative, _TunerGetWaveform>(
            'tuner_get_waveform');
  }

  // --- Demo / stub helpers ---------------------------------------------------

  double _demoFrequency() {
    _stubTick++;
    // Slowly sweep ±20 cents around A4 to demonstrate the UI.
    final deviationCents = 20.0 * math.sin(_stubTick / 120.0);
    return _stubA4 * math.pow(2.0, deviationCents / 1200.0);
  }

  double _demoCents() {
    return 20.0 * math.sin(_stubTick / 120.0);
  }

  int _demoWaveform(Float32List out) {
    final freq = 440.0; // always draw a clean 440 Hz sine for the demo
    const sampleRate = 44100.0;
    for (int i = 0; i < out.length; i++) {
      out[i] = math.sin(2 * math.pi * freq * i / sampleRate).toDouble();
    }
    return out.length;
  }
}
