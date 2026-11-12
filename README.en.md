# Zhi Yue (智阅)

> An open-source Flutter e-book reading platform for deep readers and learners.
> Local-first reading experience first, then AI-assisted learning and cross-device sync.

**[简体中文](README.md)** | **English**

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![Version](https://img.shields.io/badge/version-1.16.3--alpha-blue.svg)](https://github.com/weifu-0523/e-book-reading-platform/releases/tag/v1.16.3-alpha)

## Screenshots

| Library | EPUB Reader | PDF Reader | Notes |
|---|---|---|---|
| ![Library](docs/screenshots/library.png) | ![EPUB Reader](docs/screenshots/epub_reader.png) | ![PDF Reader](docs/screenshots/pdf_reader.png) | ![Notes](docs/screenshots/notes.png) |

## Features

### Reading (MVP 1.0 → v1.16.3-alpha)

- **Cross-platform**: Windows + Android from a single Flutter codebase
- **Formats**: EPUB (incl. double-page spread layout) + PDF (text-based & scanned, two-page on wide screens) + TXT/Markdown
- **Local-first**: all data in local SQLite, fully usable offline
- **Immersive reading**: fine typography, 4 themes (light/dark/sepia/e-ink), fullscreen mode, EPUB pagination & scroll modes
- **Annotations**: 5-color highlights, notes, bookmarks, freeform notes, tags, FTS5 full-text search
- **Knowledge export**: per-book & batch Markdown export with an Obsidian-compatible vault layout

### AI Assisted Reading (BYOK, OpenAI-compatible — DeepSeek first)

- Whole-book summary, chapter guides, highlight commentary, per-book Q&A with `[ch=N]` citation jump
- Per-book multi-session AI chat with Socratic follow-ups and slash commands (`/new` `/del` `/switch`)
- Chapter learning review: AI generates summary + key takeaways from chapter text and your highlights

### TTS (Text-to-Speech)

- Read aloud AI responses; "read this chapter" auto-follow for EPUB/PDF/TXT/Markdown with sentence-level highlighting
- Background playback on mobile (foreground service), cross-device reading-position sync
- Cloud TTS engines (Volcengine V3 SSE / Qwen) + system TTS with ROM-specific engine enumeration retry (Xiaomi/OPPO/HyperOS/ColorOS)

### Sync (Jianguoyun WebDAV, no self-hosted backend)

- Two-way sync of highlights / notes / bookmarks / progress / tags / AI chat history / book files & covers
- Last-write-wins with conflict log, outbox + debounce push, flush on close, pull on cold start

## Download

Latest artifacts are published on **GitHub Releases**: [v1.16.3-alpha](https://github.com/weifu-0523/e-book-reading-platform/releases/tag/v1.16.3-alpha).

- **Windows**: installer & portable zip (see Gitee historical releases for older versions: [v1.1.0-alpha](https://gitee.com/weifu0523/e-book-reading-platform/releases/tag/v1.1.0-alpha))
- **Android**: sideload the APK (Android 8+ needs "install unknown apps" permission); open `.epub`/`.pdf` files with Zhi Yue from your file manager

## Tech Stack

| Layer | Tech |
|---|---|
| Framework | Flutter 3.44+ |
| Language | Dart 3.10+ |
| State | Riverpod 2.5 |
| Routing | go_router 14.2 |
| Database | drift 2.18 (SQLite + FTS5) |
| EPUB | epubx 4.0.0 (local fork `epubx_patched/`) |
| PDF | pdfrx 2.3.0 |
| AI | OpenAI-compatible client (DeepSeek first) |
| TTS | flutter_tts / audio_service / cloud TTS (Volcengine V3, Qwen) |
| Sync | Jianguoyun WebDAV |
| License | AGPLv3 |

## Quality

- Tests: 1600+ passing across unit/widget/integration suites (per-release counts in release notes)
- Static analysis: 0 errors / 0 warnings
- Docs: maintainer's runbook, milestone specs & plans, release procedure

## Documentation

- [Original design doc (MVP 1.0)](docs/superpowers/specs/2026-06-24-ebook-platform-design.md) (Chinese)
- [Phase 2 roadmap](docs/superpowers/specs/2026-06-28-phase2-roadmap-design.md) (Chinese)
- [Maintainer's runbook](docs/maintainers-runbook.md) (Chinese)
- [Changelog](CHANGELOG.md) (Chinese)

## Feedback & Contributing

- GitHub Issues: https://github.com/weifu-0523/e-book-reading-platform/issues
- Gitee Issues: https://gitee.com/weifu0523/e-book-reading-platform/issues
- The project is in early development; external PRs are not accepted yet — suggestions via Issues are welcome.

## License

This project is open-sourced under the [AGPLv3](LICENSE). Every source file carries an `SPDX-License-Identifier: AGPL-3.0-or-later` header. Any modification or network-service use of this project must be released under the same license. Third-party dependency notices: [NOTICE](NOTICE).
