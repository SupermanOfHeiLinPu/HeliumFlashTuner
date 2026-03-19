import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/tuner_model.dart';
import '../widgets/oscilloscope_painter.dart';

/// The main tuner screen.
class TunerScreen extends StatefulWidget {
  const TunerScreen({super.key});

  @override
  State<TunerScreen> createState() => _TunerScreenState();
}

class _TunerScreenState extends State<TunerScreen> {
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    // Poll the native library at ~60 fps
    _tickTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      context.read<TunerModel>().tick();
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  // ---- Settings overlay -------------------------------------------------

  void _openSettings(BuildContext ctx) {
    showDialog<void>(
      context: ctx,
      builder: (_) => const _SettingsDialog(),
    );
  }

  // ---- Build ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: const Text(
          'HeliumFlash Tuner',
          style: TextStyle(
            color: Color(0xFFE6EDF3),
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Color(0xFFE6EDF3)),
            onPressed: () => _openSettings(context),
            tooltip: '设置',
          ),
        ],
      ),
      body: const _TunerBody(),
    );
  }
}

// ---------------------------------------------------------------------------
// Main body
// ---------------------------------------------------------------------------

class _TunerBody extends StatelessWidget {
  const _TunerBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        const _InfoBar(),
        const SizedBox(height: 12),
        const Expanded(child: _OscilloscopeSection()),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Info bar: frequency | note name | cents
// ---------------------------------------------------------------------------

class _InfoBar extends StatelessWidget {
  const _InfoBar();

  @override
  Widget build(BuildContext context) {
    final model = context.watch<TunerModel>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Current frequency (left)
          _InfoLabel(
            text: model.frequencyLabel,
            color: const Color(0xFF8B949E),
          ),
          // Note name (centre, prominent)
          _NoteLabel(noteName: model.noteName),
          // Cents deviation (right)
          _InfoLabel(
            text: model.centsLabel,
            color: _centsColor(model.cents, model.isDetected),
          ),
        ],
      ),
    );
  }

  Color _centsColor(double cents, bool detected) {
    if (!detected) return const Color(0xFF8B949E);
    if (cents.abs() <= 5) return const Color(0xFF00CC66);
    return const Color(0xFFFF3B30);
  }
}

class _InfoLabel extends StatelessWidget {
  const _InfoLabel({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _NoteLabel extends StatelessWidget {
  const _NoteLabel({required this.noteName});
  final String noteName;

  @override
  Widget build(BuildContext context) {
    return Text(
      noteName,
      style: const TextStyle(
        color: Color(0xFFE6EDF3),
        fontSize: 52,
        fontWeight: FontWeight.bold,
        letterSpacing: 2,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Oscilloscope section
// ---------------------------------------------------------------------------

class _OscilloscopeSection extends StatelessWidget {
  const _OscilloscopeSection();

  @override
  Widget build(BuildContext context) {
    final model = context.watch<TunerModel>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF30363D),
              width: 1,
            ),
          ),
          child: CustomPaint(
            painter: OscilloscopePainter(
              waveform: model.waveform,
              cents: model.cents,
              isDetected: model.isDetected,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Settings dialog
// ---------------------------------------------------------------------------

class _SettingsDialog extends StatefulWidget {
  const _SettingsDialog();

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  late TextEditingController _a4Controller;
  late NotationStyle _notation;

  @override
  void initState() {
    super.initState();
    final model = context.read<TunerModel>();
    _a4Controller = TextEditingController(
        text: model.a4Frequency.toStringAsFixed(1));
    _notation = model.notationStyle;
  }

  @override
  void dispose() {
    _a4Controller.dispose();
    super.dispose();
  }

  void _apply() {
    final model = context.read<TunerModel>();
    final parsed = double.tryParse(_a4Controller.text);
    if (parsed != null) model.setA4Frequency(parsed);
    model.setNotationStyle(_notation);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFFE6EDF3);
    const subColor = Color(0xFF8B949E);
    const cardColor = Color(0xFF161B22);

    return Dialog(
      backgroundColor: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '设置',
              style: TextStyle(
                  color: textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            // A4 frequency
            const Text('A4 标准音频率 (Hz)',
                style: TextStyle(color: subColor, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: _a4Controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: textColor),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF0D1117),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: Color(0xFF30363D)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: Color(0xFF30363D)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: Color(0xFF00CC66)),
                ),
                hintText: '例：440.0',
                hintStyle:
                    const TextStyle(color: Color(0xFF484F58)),
              ),
            ),
            const SizedBox(height: 20),

            // Notation style
            const Text('音名记号法',
                style: TextStyle(color: subColor, fontSize: 13)),
            const SizedBox(height: 8),
            _NotationTile(
              label: '科学音高记号法  (C4, A4 …)',
              value: NotationStyle.scientific,
              groupValue: _notation,
              onChanged: (v) => setState(() => _notation = v!),
            ),
            const SizedBox(height: 4),
            _NotationTile(
              label: '亥姆霍兹音高记号法  (c\', a\' …)',
              value: NotationStyle.helmholtz,
              groupValue: _notation,
              onChanged: (v) => setState(() => _notation = v!),
            ),
            const SizedBox(height: 28),

            // Confirm button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00CC66),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _apply,
                child: const Text('确认',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotationTile extends StatelessWidget {
  const _NotationTile({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final String label;
  final NotationStyle value;
  final NotationStyle groupValue;
  final ValueChanged<NotationStyle?> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Row(
        children: [
          Radio<NotationStyle>(
            value: value,
            groupValue: groupValue,
            onChanged: onChanged,
            fillColor: WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.selected)
                    ? const Color(0xFF00CC66)
                    : const Color(0xFF8B949E)),
          ),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFFE6EDF3), fontSize: 13)),
        ],
      ),
    );
  }
}
