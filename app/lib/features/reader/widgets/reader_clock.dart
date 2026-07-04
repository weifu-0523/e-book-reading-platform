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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 顶栏实时时钟（M3c/任务 3）。
///
/// 每秒刷新一次，显示当前时间 `HH:mm`（24h 制，[DateFormat.Hm]）。
/// 文字样式随 AppBar title 自动适应（不强制字号，由 [AppBar] 的
/// [TitleTheme] 决定）。
///
/// **Timer 生命周期**：本 widget 只在 `ReaderScaffold._buildChrome`
/// （`if (ui.chromeVisible)` 内）创建。chrome 隐藏时 `_buildChrome` 不被
/// 调用 → 本 widget 不挂载 → Timer 不启动。dispose 时 [Timer.cancel]，
/// 保证不泄漏。
///
/// [now] 可注入当前时间源（默认 [DateTime.now]），便于测试时推进时间验证
/// 文字更新。生产代码使用默认值即可。
class ReaderClock extends StatefulWidget {
  /// 当前时间源。测试可注入受控时钟以确定性推进时间。
  final DateTime Function() now;

  const ReaderClock({super.key, this.now = DateTime.now});

  @override
  State<ReaderClock> createState() => _ReaderClockState();
}

class _ReaderClockState extends State<ReaderClock> {
  /// 1 秒周期 Timer，触发 setState 刷新 `_now`。
  Timer? _timer;

  /// 当前显示的时间。每秒由 Timer 更新。
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = widget.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = widget.now());
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(DateFormat.Hm().format(_now));
  }
}
