// test_main.cpp
//
// Console-mode smoke test for zhiyue::parseBookIdFromDeepLink.
// Uses plain assert() so the test has no third-party dependency
// (no GoogleTest, no Flutter headers) and can be compiled by cl.exe
// from an ASCII working directory (the project path contains Chinese
// characters which break the MSVC compiler driver).
//
// Build/run: see run_smoke_test.bat.
//
// Exit code: 0 on success, non-zero (abort) on the first failing
// assert. CI treats any non-zero exit as failure.

#include "deep_link_parser.h"

#include <cassert>
#include <iostream>
#include <string>

namespace {

void RunTests() {
  using zhiyue::parseBookIdFromDeepLink;

  // 1. Canonical valid URI.
  assert(parseBookIdFromDeepLink("zhiyue://book/abc-123") == "abc-123");

  // 2. Valid URI with a query string — query must be stripped.
  assert(parseBookIdFromDeepLink("zhiyue://book/abc-123?chapter=4") ==
         "abc-123");

  // 3. Wrong scheme — must be exactly "zhiyue".
  assert(parseBookIdFromDeepLink("http://book/abc-123") == "");
  assert(parseBookIdFromDeepLink("zhiyues://book/abc-123") == "");

  // 4. Wrong path — must start with "book/".
  assert(parseBookIdFromDeepLink("zhiyue://library") == "");
  assert(parseBookIdFromDeepLink("zhiyue://library/abc-123") == "");

  // 5. Empty input.
  assert(parseBookIdFromDeepLink("") == "");

  // 6. No book id — trailing slash with nothing after it.
  assert(parseBookIdFromDeepLink("zhiyue://book/") == "");

  // 7. Scheme only (defensive).
  assert(parseBookIdFromDeepLink("zhiyue://") == "");
  assert(parseBookIdFromDeepLink("zhiyue:") == "");

  // 8. Book id that contains a sub-path is rejected: deep links
  //    address a single book, anything past the first segment is
  //    treated as malformed.
  assert(parseBookIdFromDeepLink("zhiyue://book/abc/def") == "");

  // 9. A UUID-shaped id (the canonical id format used by ZhiYue).
  assert(parseBookIdFromDeepLink(
            "zhiyue://book/550e8400-e29b-41d4-a716-446655440000") ==
         "550e8400-e29b-41d4-a716-446655440000");

  // 10. Fragment after the id is stripped (mirrors query handling).
  assert(parseBookIdFromDeepLink("zhiyue://book/abc-123#ch4") == "abc-123");
}

}  // namespace

int main() {
  RunTests();
  std::cout << "All deep_link_parser tests passed.\n";
  return 0;
}
