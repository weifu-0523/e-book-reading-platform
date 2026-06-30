// deep_link_parser.cpp
//
// Implementation of zhiyue::parseBookIdFromDeepLink.
//
// This is currently GREENFIELD logic: main.cpp never had inline
// deep-link parsing — the Windows runner forwards file paths
// (epub/pdf) to Dart via the dev.zhiyue.bookopen MethodChannel, and
// deep-link scheme activation is not yet wired up on Windows. The
// parser is being added now so that when scheme activation lands,
// the URI handling is already covered by a regression test.

#include "deep_link_parser.h"

#include <string>

namespace zhiyue {

namespace {

// Expected scheme + authority prefix. The deep-link scheme is
// "zhiyue" and the host is always "book" for book-open links.
// (Other hosts like "library" are valid URIs but not book-open
// requests, so they correctly fall through to the empty return.)
constexpr const char* kSchemeAndHost = "zhiyue://book/";
constexpr std::size_t kSchemeAndHostLen = 14;  // strlen("zhiyue://book/")

// Returns the index of the first character in [first, s.size()) that
// terminates the book-id segment: '?' (query), '#' (fragment), or
// '/' (sub-path — caller treats as malformed). Returns s.size() if
// none of those characters appears.
std::size_t FindIdEnd(const std::string& s, std::size_t first) {
  for (std::size_t i = first; i < s.size(); ++i) {
    const char c = s[i];
    if (c == '?' || c == '#' || c == '/') {
      return i;
    }
  }
  return s.size();
}

}  // namespace

std::string parseBookIdFromDeepLink(const std::string& uri) {
  // Reject anything shorter than the scheme+host prefix, and anything
  // that doesn't start with it (case-sensitive on purpose — the
  // registered scheme is lowercase).
  if (uri.size() < kSchemeAndHostLen ||
      uri.compare(0, kSchemeAndHostLen, kSchemeAndHost) != 0) {
    return std::string();
  }
  if (uri.size() == kSchemeAndHostLen) {
    // "zhiyue://book/" with no id — reject.
    return std::string();
  }

  const std::size_t id_start = kSchemeAndHostLen;
  const std::size_t id_end = FindIdEnd(uri, id_start);

  // Empty id ("zhiyue://book/" already handled above, but the query-
  // only form "zhiyue://book/?x=1" reaches here with id_start==id_end)
  // is rejected, as is any id containing a '/' (sub-path).
  if (id_start == id_end) {
    return std::string();
  }

  // A '/' terminator means the URI had a sub-path after the id
  // (e.g. "zhiyue://book/abc/def"). Deep links address a single
  // book, so any sub-path is rejected as malformed.
  if (id_end < uri.size() && uri[id_end] == '/') {
    return std::string();
  }

  return uri.substr(id_start, id_end - id_start);
}

}  // namespace zhiyue
