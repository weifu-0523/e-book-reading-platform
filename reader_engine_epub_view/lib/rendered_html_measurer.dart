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

import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:reader_engine/rendering/html_text_utils.dart';

import 'html_slicer.dart';
import 'typography_style_injector.dart';

/// M4.6-fix16: 用 fwfh 实际渲染测量章节 HTML 中每段的渲染高度。
/// M4.6-fix17: 修复 measurer 漏注入首行缩进（实际渲染有 EM SPACE，测量没，
///   导致测量高度 < 实际高度 → 每页塞过多内容 → 底部裁剪）；同时把 key 直接
///   挂 HtmlWidget（移除 Container 包装，避免 findRenderObject 返回 fwfh
///   外层 wrapper 的 RenderBox 而非内容本身）；用 Set<int> 跟踪已报告段，
///   避免 0 高度空段永远不触发 onMeasured。
///
/// **为什么需要这个**：
/// 旧版 [Paginator] 用 TextPainter 估算文字高度（fix15 加了图片高度估算），
/// 但实际渲染走 fwfh HtmlWidget 的自有布局引擎。两套布局系统永远存在
/// drift（line-height/font-metrics/图片实际尺寸 vs 估算），累积一页可达数行
/// 误差 → 分页器把"应到下一页的内容"塞到当前页 → 渲染时溢出可见。
/// fix12-15 多次调容差/估算都没解决根因（双测量系统）。
///
/// 本 widget 改用 fwfh 自己测量：每段（按 [HtmlTextUtils.htmlToParagraphs]
/// 切分）单独渲染一个 HtmlWidget，Offstage 不可见，layout 后通过
/// GlobalKey 拿 [RenderBox.size.height]。drift 归零——测量和实际渲染用同一
/// 引擎，结果一致。
///
/// **fix17 关键**：测量时必须与实际渲染**完全同输入**。实际渲染管线
/// （epubx_renderer._buildPaged）会对每页 HTML 调 [TypographyStyleInjector.inject]
/// 在每个 `<p>` 首个文本节点前插入 N 个 EM SPACE 全角空格（首行缩进）。
/// 测量若跳过这步，首行宽度算窄 → 换行数算少 → 高度算低 → drift。
///
/// **使用方式**：
/// 放在 widget tree 里（Offstage 自动包裹，对外不可见），等待 [onMeasured]
/// 回调。回调返回的 heights 列表与 [HtmlTextUtils.htmlToParagraphs] 输出的
/// `paragraphs` 列表同长度、同顺序，可直接喂给
/// [Paginator.paginateFromActualHeights] 算 page breaks。
///
/// **性能**：
/// 整章切成 N 段，每段独立渲染。fwfh 渲染单段平均 < 1ms（短段落）到几 ms
/// （长段落/图片）。50 段章节典型 50-150ms，比旧版 Paginator 的
/// TextPainter 估算慢约 3-5 倍，但仅在章节首次进入或排版变更时跑（缓存命中
/// 后零开销），用户可接受。详见 epubx_renderer._buildPaged 的缓存逻辑。
class RenderedHtmlMeasurer extends StatefulWidget {
  const RenderedHtmlMeasurer({
    super.key,
    required this.chapterHtml,
    required this.width,
    required this.textStyle,
    required this.imageMaxHeight,
    required this.indentEm,
    required this.indentEnabled,
    required this.onMeasured,
  });

  /// 完整章节 HTML（含 `<p>`、`<img>` 等所有标签）。
  final String chapterHtml;

  /// 测量宽度（= 实际渲染时 HtmlWidget 的可用宽度，typically
  /// `viewport.width - 2 * margin`）。测量与实际渲染宽度必须一致，
  /// 否则换行数不同 → 高度不同 → drift。
  final double width;

  /// 文字样式（与实际渲染的 HtmlWidget textStyle 一致）。
  final TextStyle textStyle;

  /// 图片 max-height（与实际渲染一致，typically `viewport.height * 0.6`）。
  final double imageMaxHeight;

  /// M4.6-fix17: 首行缩进 em 值，与 [TypographyStyleInjector.inject] 同义。
  /// 必须与实际渲染（epubx_renderer._buildPaged 调 inject 时传入的值）一致。
  final double indentEm;

  /// M4.6-fix17: 是否启用首行缩进。同上，必须一致。
  final bool indentEnabled;

  /// 测量完成回调。返回 heights 列表（与 HtmlTextUtils.htmlToParagraphs
  /// 输出的 paragraphs 同长度、同顺序）。在 widget 完全 layout 后触发，
  /// 调用方可直接读取结果触发 rebuild。
  final void Function(List<double> heights) onMeasured;

  @override
  State<RenderedHtmlMeasurer> createState() => _RenderedHtmlMeasurerState();
}

class _RenderedHtmlMeasurerState extends State<RenderedHtmlMeasurer> {
  late final List<String> _paragraphHtmls;
  final List<double> _heights = <double>[];
  // M4.6-fix17: 用 Set 跟踪已报告段下标，避免空段（高度=0）永不触发完成。
  final Set<int> _reported = <int>{};
  bool _done = false;

  @override
  void initState() {
    super.initState();
    final parsed = HtmlTextUtils.htmlToParagraphs(widget.chapterHtml);
    final plainText = parsed.plainText;
    final paragraphs = parsed.paragraphs;

    // 用 HtmlSlicer.sliceByPlainRangeDoc 把每段切成独立 HTML 片段。
    // 共享预解析 Document（M4.6-fix10/A3 性能优化），避免每段重新 parse。
    final doc = html_parser.HtmlParser(widget.chapterHtml).parse();
    for (final el in doc.querySelectorAll('script, style')) {
      el.remove();
    }
    // M4.6-fix17: 与实际渲染管线 (_buildPaged) 完全一致——每段 HTML 也要
    // 经过 TypographyStyleInjector.inject 注入 EM SPACE 首行缩进，否则测量
    // 高度 < 实际渲染高度（实际首行被缩进推宽 → 提前换行 → 多 1 行 → 更高）。
    _paragraphHtmls = [
      for (final p in paragraphs)
        TypographyStyleInjector.inject(
          HtmlSlicer.sliceByPlainRangeDoc(
            doc,
            p.start,
            p.end,
            plainLength: plainText.length,
          ),
          indentEm: widget.indentEm,
          enabled: widget.indentEnabled,
        ),
    ];
    _heights.addAll(List<double>.filled(_paragraphHtmls.length, 0.0));
  }

  void _onParagraphMeasured(int idx, double height) {
    if (!mounted) return;
    if (idx < 0 || idx >= _heights.length) return;
    // M4.6-fix17: 用 Set 跟踪，避免 0 高度空段（_MeasuredParagraph 可能因
    // layout 调度重复触发或空段 height=0）卡住 _reportedCount。
    if (_reported.contains(idx)) return;
    _reported.add(idx);
    _heights[idx] = height;
    if (_reported.length == _heights.length && !_done) {
      _done = true;
      // 下一帧回调，避免在 build/layout 阶段触发 setState 链。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onMeasured(List<double>.of(_heights));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Offstage：保留 layout（测量有效），但不可见（用户体验无干扰）。
    // 注意：Offstage(offstage: true) 仍会触发 layout（与 Visibility 不同），
    // 是 Flutter 测量子 widget 高度的标准做法。
    return Offstage(
      child: SizedBox(
        width: widget.width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < _paragraphHtmls.length; i++)
              _MeasuredParagraph(
                key: ValueKey<int>(i),
                idx: i,
                html: _paragraphHtmls[i],
                textStyle: widget.textStyle,
                imageMaxHeight: widget.imageMaxHeight,
                onMeasured: _onParagraphMeasured,
              ),
          ],
        ),
      ),
    );
  }
}

/// 单段测量 widget：渲染一个 HtmlWidget 包裹的段落 HTML，layout 后报告高度。
///
/// [initState] 里 schedule post-frame callback 拿 [RenderBox.size.height]，
/// 回调 [widget.onMeasured]。若首帧 RenderObject 还未挂载或没有 size，
/// 重新 schedule 下一帧（最多重试几次，防御性）。
///
/// M4.6-fix17: key 直接挂在 HtmlWidget 上（移除原 Container 包装）。
/// 原因：findRenderObject 返回 widget 树中第一个 RenderObject，Container
/// 包装层会让 findRenderObject 落到 fwfh 的外层 wrapper RenderBox（可能含
/// padding），而不是 HtmlWidget 的内容 RenderBox。直接 key HtmlWidget 确保
/// 拿到内容真实高度。
class _MeasuredParagraph extends StatefulWidget {
  const _MeasuredParagraph({
    super.key,
    required this.idx,
    required this.html,
    required this.textStyle,
    required this.imageMaxHeight,
    required this.onMeasured,
  });

  final int idx;
  final String html;
  final TextStyle textStyle;
  final double imageMaxHeight;
  final void Function(int idx, double height) onMeasured;

  @override
  State<_MeasuredParagraph> createState() => _MeasuredParagraphState();
}

class _MeasuredParagraphState extends State<_MeasuredParagraph> {
  final GlobalKey _key = GlobalKey();
  bool _reported = false;
  int _attempts = 0;
  static const int _maxAttempts = 5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    if (!mounted || _reported) return;
    _attempts += 1;
    final ctx = _key.currentContext;
    if (ctx == null) {
      // 还没 layout，重试。
      if (_attempts < _maxAttempts) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
      }
      return;
    }
    final ro = ctx.findRenderObject();
    if (ro is! RenderBox || !ro.hasSize) {
      if (_attempts < _maxAttempts) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
      }
      return;
    }
    _reported = true;
    widget.onMeasured(widget.idx, ro.size.height);
  }

  @override
  Widget build(BuildContext context) {
    // M4.6-fix17: key 直接挂 HtmlWidget（无 Container 包装）。
    return HtmlWidget(
      key: _key,
      widget.html,
      textStyle: widget.textStyle,
      // customStylesBuilder 必须与实际渲染的 _elementStyles 完全一致，
      // 否则测量与实际渲染高度 drift。沿用 epubx_renderer._elementStyles
      // 同语义：p 段落 margin 0 0 0.5em 0；img max-height + height: auto。
      customStylesBuilder: (dom.Element element) =>
          _elementStyles(element, widget.imageMaxHeight),
    );
  }
}

Map<String, String>? _elementStyles(dom.Element element, double maxImgHeightPx) {
  final tag = element.localName;
  if (tag == 'p') {
    return const <String, String>{'margin': '0 0 0.5em 0'};
  }
  if (tag == 'img') {
    return <String, String>{
      'max-height': '${maxImgHeightPx.round()}px',
      'height': 'auto',
    };
  }
  return null;
}
