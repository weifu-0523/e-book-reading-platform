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

/// A single historical turn in a chat conversation.
///
/// Roles: `'user'` | `'ai'` | `'system'`. System turns are filtered out
/// by [PromptBuilderExt.buildChatPrompt] (they exist as in-DB markers
/// like "苏格拉底模式启动" but should not be re-rendered as user/ai lines).
class ChatTurn {
  const ChatTurn({required this.role, required this.content});
  final String role;
  final String content;
}

/// Builds prompts for the M2.7 AI chat drawer.
///
/// Three responsibilities:
/// 1. Chat turns -> LLM prompt (mode-aware: normal vs socratic system prompt)
/// 2. Socratic bootstrap (recap -> first-question prompt for AI to open)
/// 3. Recap (chapter text -> 3-5 bullet points)
///
/// Pure (no LLM/DB access). All state comes in via parameters.
class PromptBuilderExt {
  const PromptBuilderExt._();

  static const _socraticSystemPrompt = '''你是苏格拉底式导师。
规则：
- 不要直接给出答案
- 通过反问、追问引导学生自己思考
- 检测到学生疲惫或想结束时，做一段本章收束回顾
- 始终用中文''';

  static const _normalSystemPrompt = '''你是一个阅读助手，回答用户关于本书的问题。始终用中文。''';

  /// Builds the prompt for a user free-form message.
  ///
  /// - [history]: all prior turns in the session (excludes the just-typed
  ///   pendingUserContent). System turns are filtered.
  /// - [mode]: 'normal' | 'socratic'. Affects which system prompt is prepended.
  /// - [pendingUserContent]: the user's just-typed message (will be appended).
  /// - [attachmentSnapshot]: optional note body attached via `@` mention.
  ///   Inserted between history and pending user content.
  static String buildChatPrompt({
    required List<ChatTurn> history,
    required String mode,
    String? pendingUserContent,
    String? attachmentSnapshot,
  }) {
    final sys = mode == 'socratic' ? _socraticSystemPrompt : _normalSystemPrompt;
    final buf = StringBuffer('$sys\n\n');

    // Render history (skip system markers — they're DB-level annotations).
    for (final turn in history) {
      if (turn.role == 'system') continue;
      final speaker = turn.role == 'user' ? '用户' : 'AI';
      buf.writeln('$speaker: ${turn.content}');
    }

    // Append attachment block (between history and pending message).
    if (attachmentSnapshot != null && attachmentSnapshot.isNotEmpty) {
      buf
        ..writeln('\n[用户附加笔记]')
        ..writeln(attachmentSnapshot);
    }

    // Append pending user content + signal model to continue as AI.
    if (pendingUserContent != null && pendingUserContent.isNotEmpty) {
      buf
        ..writeln('\n用户: $pendingUserContent')
        ..writeln('AI:');
    }

    return buf.toString();
  }

  /// Builds the socratic bootstrap prompt.
  ///
  /// Given a recap of the current chapter, asks the LLM to open the
  /// socratic session with a single open-ended question (NOT a lecture).
  ///
  /// 2026-07-08 BUG C: 增加 [chapterGuide] 可选参数。用户工作流常是
  /// 「先点本章导读 → 再点苏格拉底」，此时本会话里已经有 chapter guide
  /// 的 AI 输出。若只传 recap（可能为空，因为 recap 是独立的 /recap 命令
  /// 产物），LLM 看到 "下面是本章回顾：" + 空内容，会回复"看到你提到了
  /// 本章回顾但没看到具体内容"。优先把 chapter guide 当作"本章要点"
  /// 传入，没有时再用 recap 兜底。
  static String buildSocraticBootstrapPrompt({
    required String recap,
    String? chapterGuide,
  }) {
    final guide = chapterGuide?.trim();
    final effectiveGuide = (guide != null && guide.isNotEmpty) ? guide : recap;
    final sectionLabel = (guide != null && guide.isNotEmpty)
        ? '本章要点（来自本章导读）'
        : '本章回顾';
    return '''$_socraticSystemPrompt

下面是$sectionLabel：
$effectiveGuide

请基于其中任意一个关键点，向学生提一个开放性问题。
规则：
- 不要直接讲解内容
- 提一个问题，让学生用自己的话回答
- 用中文''';
  }

  /// Builds the recap prompt for [RunRecapUseCase].
  ///
  /// Asks the LLM to summarize the chapter as 3-5 bullet points.
  static String buildRecapPrompt({required String chapterText}) {
    return '''请回顾以下章节内容，列出 3-5 个关键点（每点带简短说明）：

$chapterText

输出格式：
• 关键点 1 - 说明
• 关键点 2 - 说明
...''';
  }
}
