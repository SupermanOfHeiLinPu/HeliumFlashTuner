#pragma once
// ---------------------------------------------------------------------------
// TunerBridge – C API exported for Flutter FFI
// ---------------------------------------------------------------------------

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_WIN32)
  #define TUNER_EXPORT __declspec(dllexport)
#else
  #define TUNER_EXPORT __attribute__((visibility("default")))
#endif

/// Initialise the tuner with the given sample rate.
/// Must be called once before any other function.
TUNER_EXPORT void tuner_init (int sampleRate);

/// Start audio capture.
TUNER_EXPORT void tuner_start ();

/// Stop audio capture.
TUNER_EXPORT void tuner_stop ();

/// Release all resources.
TUNER_EXPORT void tuner_cleanup ();

/// Set the A4 reference frequency (Hz).  Default: 440.
TUNER_EXPORT void tuner_set_a4_frequency (double freq);

/// Get the current A4 reference frequency (Hz).
TUNER_EXPORT double tuner_get_a4_frequency ();

/// Get the last detected fundamental frequency (Hz).  0 if not detected.
TUNER_EXPORT double tuner_get_frequency ();

/// Get the cents deviation from the nearest semitone.
TUNER_EXPORT double tuner_get_cents ();

/// Get the MIDI note number of the nearest semitone.  -1 if not detected.
TUNER_EXPORT int tuner_get_midi_note ();

/// Get the pitch-detection confidence (0–1).
TUNER_EXPORT double tuner_get_confidence ();

/// Copy up to [maxSamples] waveform samples into [buffer].
/// Returns the actual number of samples written.
TUNER_EXPORT int tuner_get_waveform (float* buffer, int maxSamples);

/// Set the noise-floor threshold (dBFS, e.g. -60.0).
/// Signals below this level are ignored.
TUNER_EXPORT void tuner_set_noise_floor (double dBFS);

#ifdef __cplusplus
} // extern "C"
#endif
