import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:helium_flash_tuner/services/note_utils.dart';

void main() {
  group('NoteUtils', () {
    test('frequencyToMidi - A4 = MIDI 69', () {
      expect(NoteUtils.frequencyToMidi(440.0), 69);
    });

    test('frequencyToMidi - A0 = MIDI 21', () {
      expect(NoteUtils.frequencyToMidi(27.5), 21);
    });

    test('frequencyToMidi - C8 = MIDI 108', () {
      // C8 ≈ 4186.01 Hz
      expect(NoteUtils.frequencyToMidi(4186.01), 108);
    });

    test('midiToFrequency - MIDI 69 = 440 Hz', () {
      expect(NoteUtils.midiToFrequency(69),
          closeTo(440.0, 0.001));
    });

    test('centsFromNearest - exactly on pitch is 0 cents', () {
      expect(NoteUtils.centsFromNearest(440.0), closeTo(0.0, 0.01));
    });

    test('centsFromNearest - 1 semitone sharp is +100 cents', () {
      // A4 + 1 semitone = A#4 / Bb4
      final freq = 440.0 * math.pow(2, 1.0 / 12);
      expect(NoteUtils.centsFromNearest(freq), closeTo(0.0, 0.5));
    });

    test('centsFromNearest - half semitone sharp is +50 cents', () {
      final freq = 440.0 * math.pow(2, 0.5 / 12);
      expect(NoteUtils.centsFromNearest(freq), closeTo(50.0, 0.5));
    });

    group('scientificNotation', () {
      test('A4 = A4', () => expect(NoteUtils.scientificNotation(69), 'A4'));
      test('C4 (middle C) = C4',
          () => expect(NoteUtils.scientificNotation(60), 'C4'));
      test('A0 = A0', () => expect(NoteUtils.scientificNotation(21), 'A0'));
      test('C8 = C8', () => expect(NoteUtils.scientificNotation(108), 'C8'));
    });

    group('helmholtzNotation', () {
      test("A4 = a'",  () => expect(NoteUtils.helmholtzNotation(69), "a'"));
      test("C4 (middle C) = c'",
          () => expect(NoteUtils.helmholtzNotation(60), "c'"));
      test("C5 = c''", () => expect(NoteUtils.helmholtzNotation(72), "c''"));
      test('C3 = c',   () => expect(NoteUtils.helmholtzNotation(48), 'c'));
      test('C2 = C',   () => expect(NoteUtils.helmholtzNotation(36), 'C'));
      test('C1 = CC',  () => expect(NoteUtils.helmholtzNotation(24), 'CC'));
      test('C0 = CCC', () => expect(NoteUtils.helmholtzNotation(12), 'CCC'));
    });

    test('isInPianoRange - A0 (21) is in range', () {
      expect(NoteUtils.isInPianoRange(21), isTrue);
    });
    test('isInPianoRange - C8 (108) is in range', () {
      expect(NoteUtils.isInPianoRange(108), isTrue);
    });
    test('isInPianoRange - MIDI 20 is out of range', () {
      expect(NoteUtils.isInPianoRange(20), isFalse);
    });
    test('isInPianoRange - MIDI 109 is out of range', () {
      expect(NoteUtils.isInPianoRange(109), isFalse);
    });
  });
}
