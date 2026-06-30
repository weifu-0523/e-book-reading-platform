# Screenshots

This directory hosts Windows release-build screenshots used in the root
`README.md` and the Gitee Release attachments.

## Current state (2026-06-30, M1.6 T14)

| File          | Status      | Captured in |
|---------------|-------------|-------------|
| `epub_reader.png` | present (2208x1200) | M8 T14 (`bfee397`) |
| `library.png`     | **pending** | — |
| `pdf_reader.png`  | **pending** | — |
| `notes.png`       | **pending** | — |

The 3 pending shots are blocked on a manual capture step (see below).
M8 T14 captured the EPUB shot via the Win32 `PrintWindow` API; the
remaining 3 require interactive UI navigation (importing a book,
opening the reader, switching to the notes page) that an automated
subagent cannot drive.

## What each pending screenshot should show

### `library.png`

- App at launch, library page visible
- 2-3 imported books in the grid (mix of EPUB + PDF ideally)
- Should demonstrate the M1.6 `EmptyView` polish if no books are
  present, OR a populated grid if books exist
- Cover aspect ratio should be visible (M3.1 cover rendering)

### `pdf_reader.png`

- Reader open on a PDF book (use any PDF in `app/test/fixtures/`)
- Chapter drawer open OR page indicator visible
- Typography controls (font size adjuster) shown if possible
- Demonstrates M4 Page-as-Chapter + scanning-fallback polish

### `notes.png`

- Notes page for a book with at least one highlight + one annotation
- Grouped by chapter (M3.4 per-book NotesPage)
- Markdown export button visible
- Demonstrates M3.2 5-color highlight + M3.4 Markdown export

## How to capture (manual)

The Windows release build cannot be produced in the current dev
environment from the subagent: the path
`H:\projiect\电子书阅读平台\app` contains non-ASCII characters which
break `flutter_assemble`'s `app.dill` read step (mojibake in the
generated MSBuild path). Use a clean ASCII path or the pre-built
release artifact from a prior Gitee release.

Once a working release build is available:

```cmd
:: 1. Run the app
build\windows\x64\runner\Release\zhiyue.exe

:: 2. For each of the 3 missing shots:
::    - Library: launch the app, ensure 2-3 books imported
::    - PDF Reader: open a PDF, optionally open chapter drawer
::    - Notes: open a book with highlights, switch to Notes tab

:: 3. Capture with Win+Shift+S -> save to this directory

:: 4. Commit
git add docs/screenshots/library.png docs/screenshots/pdf_reader.png docs/screenshots/notes.png
git commit -m "docs: v1.0.0 release screenshots (library/pdf/notes)"
```

Alternative programmatic capture (M8 T14 approach): use Win32
`PrintWindow(hwnd, hdc, PW_RENDERFULLCONTENT)` from a small C++/Python
helper after restoring the window from iconic state. The M8 helper was
not committed; reimplement if needed.

See also `docs/release-procedure.md` step 9 and
`docs/maintainers-runbook.md` §7.6.
