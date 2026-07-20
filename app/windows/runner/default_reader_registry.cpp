#include "default_reader_registry.h"

#include <windows.h>
#include <shlobj.h>

namespace zhiyue {

std::optional<std::wstring> ReadAssocForExtension(const std::wstring& ext) {
  // Step 1: read HKCU\Software\Classes\<ext> default value (progid)
  HKEY ext_key;
  std::wstring path = L"Software\\Classes\\" + ext;
  if (RegOpenKeyExW(HKEY_CURRENT_USER, path.c_str(), 0, KEY_READ, &ext_key)
      != ERROR_SUCCESS) {
    return std::nullopt;
  }
  wchar_t progid[MAX_PATH];
  DWORD progid_size = sizeof(progid);
  DWORD type;
  LSTATUS rc = RegQueryValueExW(ext_key, nullptr, nullptr, &type,
      reinterpret_cast<LPBYTE>(progid), &progid_size);
  RegCloseKey(ext_key);
  if (rc != ERROR_SUCCESS || type != REG_SZ) return std::nullopt;

  // Step 2: read HKCU\Software\Classes\<progid>\shell\open\command
  std::wstring cmd_path =
      L"Software\\Classes\\" + std::wstring(progid) + L"\\shell\\open\\command";
  HKEY cmd_key;
  if (RegOpenKeyExW(HKEY_CURRENT_USER, cmd_path.c_str(), 0, KEY_READ, &cmd_key)
      != ERROR_SUCCESS) {
    return std::nullopt;
  }
  wchar_t cmd[MAX_PATH * 2];
  DWORD cmd_size = sizeof(cmd);
  rc = RegQueryValueExW(cmd_key, nullptr, nullptr, &type,
      reinterpret_cast<LPBYTE>(cmd), &cmd_size);
  RegCloseKey(cmd_key);
  if (rc != ERROR_SUCCESS) return std::nullopt;
  return std::wstring(cmd);
}

bool SetDefaultReaderForExtension(const std::wstring& ext,
                                  const std::wstring& exe_path) {
  // Choose progid by extension
  std::wstring progid;
  if (ext == L".epub") {
    progid = L"ZhiYue.Book";
  } else if (ext == L".pdf") {
    progid = L"ZhiYue.Pdf";
  } else {
    progid = L"ZhiYue.File";
  }

  // 1. HKCU\Software\Classes\<ext> = progid
  std::wstring ext_path = L"Software\\Classes\\" + ext;
  HKEY ext_key;
  if (RegCreateKeyExW(HKEY_CURRENT_USER, ext_path.c_str(), 0, nullptr, 0,
          KEY_WRITE, nullptr, &ext_key, nullptr) != ERROR_SUCCESS) {
    return false;
  }
  LSTATUS rc = RegSetValueExW(ext_key, nullptr, 0, REG_SZ,
      reinterpret_cast<const BYTE*>(progid.c_str()),
      static_cast<DWORD>((progid.size() + 1) * sizeof(wchar_t)));
  RegCloseKey(ext_key);
  if (rc != ERROR_SUCCESS) return false;

  // 2. HKCU\Software\Classes\<progid> = "ZhiYue Document" (friendly name)
  std::wstring progid_path = L"Software\\Classes\\" + progid;
  HKEY progid_key;
  if (RegCreateKeyExW(HKEY_CURRENT_USER, progid_path.c_str(), 0, nullptr, 0,
          KEY_WRITE, nullptr, &progid_key, nullptr) != ERROR_SUCCESS) {
    return false;
  }
  std::wstring friendly = L"ZhiYue Document";
  RegSetValueExW(progid_key, nullptr, 0, REG_SZ,
      reinterpret_cast<const BYTE*>(friendly.c_str()),
      static_cast<DWORD>((friendly.size() + 1) * sizeof(wchar_t)));

  // 3. <progid>\shell\open\command = '"exe_path" "%1"'
  HKEY cmd_key;
  std::wstring cmd_subpath = progid_path + L"\\shell\\open\\command";
  if (RegCreateKeyExW(HKEY_CURRENT_USER, cmd_subpath.c_str(), 0, nullptr, 0,
          KEY_WRITE, nullptr, &cmd_key, nullptr) != ERROR_SUCCESS) {
    RegCloseKey(progid_key);
    return false;
  }
  std::wstring cmd = L"\"" + exe_path + L"\" \"%1\"";
  rc = RegSetValueExW(cmd_key, nullptr, 0, REG_SZ,
      reinterpret_cast<const BYTE*>(cmd.c_str()),
      static_cast<DWORD>((cmd.size() + 1) * sizeof(wchar_t)));
  RegCloseKey(cmd_key);
  RegCloseKey(progid_key);
  if (rc != ERROR_SUCCESS) return false;

  // 4. Notify Explorer to refresh
  SHChangeNotify(SHCNE_ASSOCCHANGED, SHCNF_IDLIST, nullptr, nullptr);
  return true;
}

}  // namespace zhiyue
