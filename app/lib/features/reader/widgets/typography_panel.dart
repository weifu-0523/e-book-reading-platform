import 'package:flutter/material.dart';
import 'package:reader_engine/core/typography_settings.dart';

class TypographyPanel extends StatelessWidget {
  final TypographySettings current;
  final ValueChanged<TypographySettings> onChanged;

  const TypographyPanel({
    super.key,
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('字号', style: Theme.of(context).textTheme.titleSmall),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: () => _changeFontSize(current.fontSize - 1),
              ),
              Expanded(
                child: Text(
                  current.fontSize.toStringAsFixed(0),
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => _changeFontSize(current.fontSize + 1),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('主题', style: Theme.of(context).textTheme.titleSmall),
          Wrap(
            spacing: 8,
            children: ReadingTheme.values
                .map((t) => ChoiceChip(
                      label: Text(_themeLabel(t)),
                      selected: current.theme == t,
                      onSelected: (_) => onChanged(current.copyWith(theme: t)),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  void _changeFontSize(double newSize) {
    final clamped = newSize.clamp(12.0, 32.0);
    onChanged(current.copyWith(fontSize: clamped));
  }

  String _themeLabel(ReadingTheme t) {
    switch (t) {
      case ReadingTheme.light:
        return '白';
      case ReadingTheme.dark:
        return '深';
      case ReadingTheme.sepia:
        return '黄';
      case ReadingTheme.eInk:
        return '墨';
    }
  }
}
