import 'package:flutter/material.dart';
import 'package:reader_engine/core/typography_settings.dart';

/// 阅读排版设置面板。
/// 在 M2 字号/主题基础上，M3.1 补全行距、字体、页边距三项。
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
    return SingleChildScrollView(
      child: Container(
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
                      onSelected: (_) =>
                          onChanged(current.copyWith(theme: t)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),

          Text('行距', style: Theme.of(context).textTheme.titleSmall),
          Wrap(
            spacing: 8,
            children: [
              ('紧凑', 1.2),
              ('标准', 1.5),
              ('宽松', 1.8),
            ]
                .map((p) => ChoiceChip(
                      label: Text(p.$1),
                      selected: (current.lineHeight - p.$2).abs() < 0.01,
                      onSelected: (_) =>
                          onChanged(current.copyWith(lineHeight: p.$2)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),

          Text('字体', style: Theme.of(context).textTheme.titleSmall),
          Wrap(
            spacing: 8,
            children: [
              ('系统', null),
              ('衬线', 'serif'),
              ('无衬线', 'sans-serif'),
            ]
                .map((p) => ChoiceChip(
                      label: Text(p.$1),
                      selected: current.fontFamily == p.$2,
                      onSelected: (_) =>
                          onChanged(current.copyWith(fontFamily: p.$2)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),

          Text('页边距', style: Theme.of(context).textTheme.titleSmall),
          Wrap(
            spacing: 8,
            children: PageMargin.values
                .map((m) => ChoiceChip(
                      label: Text(_marginLabel(m)),
                      selected: current.pageMargin == m,
                      onSelected: (_) =>
                          onChanged(current.copyWith(pageMargin: m)),
                    ))
                .toList(),
          ),
        ],
        ),
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

  String _marginLabel(PageMargin m) {
    switch (m) {
      case PageMargin.compact:
        return '紧凑';
      case PageMargin.normal:
        return '标准';
      case PageMargin.wide:
        return '宽松';
    }
  }
}
