import 'package:meta/meta.dart';

import 'typography_settings.dart';

@immutable
class TypographyProfile {
  final String id;
  final String name;
  final TypographySettings settings;
  final bool isDefault;

  const TypographyProfile({
    required this.id,
    required this.name,
    required this.settings,
    required this.isDefault,
  });

  TypographyProfile copyWith({
    String? name,
    TypographySettings? settings,
    bool? isDefault,
  }) {
    return TypographyProfile(
      id: id,
      name: name ?? this.name,
      settings: settings ?? this.settings,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}
