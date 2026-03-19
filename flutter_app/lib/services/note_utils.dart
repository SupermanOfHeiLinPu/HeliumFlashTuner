import 'dart:math';

/// Utilities for pitch/note calculations.
class NoteUtils {
  /// Returns the MIDI note number for a given frequency (using A4 reference).
  static int frequencyToMidi(double frequency, {double a4 = 440.0}) {
    if (frequency <= 0) return -1;
    return (69 + 12 * log(frequency / a4) / ln2).round();
  }

  /// Returns the exact (fractional) MIDI note for a frequency.
  static double frequencyToMidiExact(double frequency, {double a4 = 440.0}) {
    if (frequency <= 0) return -1;
    return 69 + 12 * log(frequency / a4) / ln2;
  }

  /// Returns the reference frequency for a given MIDI note.
  static double midiToFrequency(int midi, {double a4 = 440.0}) {
    return a4 * pow(2.0, (midi - 69) / 12.0);
  }

  /// Returns cents deviation of [frequency] from the nearest semitone.
  /// Positive means sharp, negative means flat.
  static double centsFromNearest(double frequency, {double a4 = 440.0}) {
    if (frequency <= 0) return 0;
    final exactMidi = frequencyToMidiExact(frequency, a4: a4);
    final nearestMidi = exactMidi.round();
    return (exactMidi - nearestMidi) * 100.0;
  }

  /// Returns cents deviation from a specific target MIDI note.
  static double centsFromMidi(double frequency, int midi,
      {double a4 = 440.0}) {
    if (frequency <= 0) return 0;
    final targetFreq = midiToFrequency(midi, a4: a4);
    return 1200 * log(frequency / targetFreq) / ln2;
  }

  // ------- Scientific Pitch Notation -------
  static const List<String> _scientificNames = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',
  ];

  /// MIDI 21 = A0, MIDI 108 = C8 (piano range).
  static String scientificNotation(int midi) {
    if (midi < 0 || midi > 127) return '--';
    final name = _scientificNames[midi % 12];
    final octave = (midi ~/ 12) - 1;
    return '$name$octave';
  }

  // ------- Helmholtz Pitch Notation -------
  // Scientific octave 2 (MIDI 36-47):  C, D …     great octave (uppercase, no suffix)
  // Scientific octave 1 (MIDI 24-35):  CC, DD …   contra octave
  // Scientific octave 0 (MIDI 12-23):  CCC, DDD … sub-contra octave
  // Scientific octave 3 (MIDI 48-59):  c, d …     small octave (lowercase, no suffix)
  // Scientific octave 4 (MIDI 60-71):  c', d' …   one-line octave
  // Scientific octave 5 (MIDI 72-83):  c'', d'' … two-line octave  (etc.)

  static const List<String> _helmholtzNamesUpper = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',
  ];
  static const List<String> _helmholtzNamesLower = [
    'c', 'c#', 'd', 'd#', 'e', 'f', 'f#', 'g', 'g#', 'a', 'a#', 'b',
  ];

  static String helmholtzNotation(int midi) {
    if (midi < 0 || midi > 127) return '--';
    final octave = (midi ~/ 12) - 1; // scientific octave (C4 → 4, C3 → 3 …)
    final noteIndex = midi % 12;

    if (octave >= 3) {
      // Small octave (3) and above: lowercase + apostrophes
      final base = _helmholtzNamesLower[noteIndex];
      final apostrophes = octave - 3; // small(3)→0, one-line(4)→1, two-line(5)→2 …
      return apostrophes == 0 ? base : '$base${"'" * apostrophes}';
    } else {
      // Great octave (2) and below: uppercase, repeated
      // great(2) → 1 rep, contra(1) → 2 reps, sub-contra(0) → 3 reps …
      final base = _helmholtzNamesUpper[noteIndex];
      final reps = (3 - octave).clamp(1, 6);
      return base * reps;
    }
  }

  /// Returns note name according to [useHelmholtz].
  static String noteName(int midi, {bool useHelmholtz = false}) {
    return useHelmholtz ? helmholtzNotation(midi) : scientificNotation(midi);
  }

  /// Clamps a MIDI note to the piano 88-key range (A0=21 … C8=108).
  static bool isInPianoRange(int midi) => midi >= 21 && midi <= 108;
}
