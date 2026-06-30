// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TypographyProfile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          settings == other.settings &&
          isDefault == other.isDefault;

  @override
  int get hashCode => Object.hash(id, name, settings, isDefault);
}
