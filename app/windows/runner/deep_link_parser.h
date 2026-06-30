// deep_link_parser.h
//
// Extracted from main.cpp so the deep-link URI parsing logic can be
// unit-tested without booting Flutter (main.cpp is a wWinMain entry
// point and cannot be linked into a console test harness).
//
// The parser is intentionally narrow: it only recognises the
// "zhiyue://book/<id>" shape used by the ZhiYue deep-link scheme.
// Anything else returns an empty string so the caller can treat it
// as "not a book-open request".
//
// See test_main.cpp for the contract tests and
// run_smoke_test.bat for the build/run wrapper.

#pragma once

#include <string>

namespace zhiyue {

// Parses a Windows deep-link URI (e.g., "zhiyue://book/abc-123") and
// returns the book ID, or an empty string if the URI is malformed or
// doesn't match the expected scheme/path.
//
// The function is pure: no global state, no allocations beyond the
// returned std::string. It is safe to call from any thread.
//
// Accepted shape (case-sensitive):
//   zhiyue://book/<id>
//   zhiyue://book/<id>?<query>
// where <id> is non-empty and contains no '/' or '?'.
std::string parseBookIdFromDeepLink(const std::string& uri);

}  // namespace zhiyue
