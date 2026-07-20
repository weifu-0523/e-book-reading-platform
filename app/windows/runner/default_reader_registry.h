#pragma once

#include <optional>
#include <string>

namespace zhiyue {

/// Reads the current HKCU file association command for [ext] (e.g. L".epub").
/// Returns the shell/open/command string (typically `"path\zhiyue.exe" "%1"`),
/// or nullopt if no association exists for the current user.
std::optional<std::wstring> ReadAssocForExtension(const std::wstring& ext);

/// Sets HKCU\Software\Classes\<ext> to point at [exe_path] for shell/open.
/// Writes both the progid (ZhiYue.Book / ZhiYue.Pdf) and the open command.
/// Calls SHChangeNotify to refresh Explorer's icon cache.
/// Returns true on success, false on any registry error.
bool SetDefaultReaderForExtension(const std::wstring& ext,
                                  const std::wstring& exe_path);

}  // namespace zhiyue
