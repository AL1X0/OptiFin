#include "crash_report.h"

#include <windows.h>
#include <dbghelp.h>
#include <psapi.h>
#include <shlobj.h>

#include <cstdio>
#include <string>

#pragma comment(lib, "dbghelp.lib")

namespace {

std::wstring LogDirectory() {
  PWSTR roaming = nullptr;
  std::wstring dir;
  if (SUCCEEDED(SHGetKnownFolderPath(FOLDERID_RoamingAppData, 0, nullptr, &roaming))) {
    dir = std::wstring(roaming) + L"\\app.optifin\\optifin\\";
    CoTaskMemFree(roaming);
  }
  return dir;
}

LONG WINAPI OnCrash(EXCEPTION_POINTERS* info) {
  const std::wstring dir = LogDirectory();
  if (dir.empty()) return EXCEPTION_CONTINUE_SEARCH;
  const auto* record = info->ExceptionRecord;
  const auto address = reinterpret_cast<uintptr_t>(record->ExceptionAddress);

  // Module contenant l'adresse fautive (ex. libmpv-2.dll + 0x1234).
  wchar_t module_name[MAX_PATH] = L"?";
  uintptr_t offset = address;
  HMODULE module = nullptr;
  if (GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                         reinterpret_cast<LPCWSTR>(record->ExceptionAddress), &module)) {
    wchar_t path[MAX_PATH];
    GetModuleFileNameW(module, path, MAX_PATH);
    const wchar_t* slash = wcsrchr(path, L'\\');
    wcsncpy_s(module_name, slash ? slash + 1 : path, _TRUNCATE);
    offset = address - reinterpret_cast<uintptr_t>(module);
  }

  SYSTEMTIME t;
  GetLocalTime(&t);
  FILE* log = nullptr;
  if (_wfopen_s(&log, (dir + L"optifin.log").c_str(), L"a, ccs=UTF-8") == 0 && log) {
    fwprintf(log, L"%02d:%02d:%02d.%03d E/crash: Plantage natif — code 0x%08lX dans %s + 0x%llX (crash.dmp)\n",
             t.wHour, t.wMinute, t.wSecond, t.wMilliseconds, record->ExceptionCode, module_name,
             static_cast<unsigned long long>(offset));
    fclose(log);
  }

  // Petit vidage (pile des threads, modules) : quelques centaines de Ko, aucune donnée de l'app.
  HANDLE file = CreateFileW((dir + L"crash.dmp").c_str(), GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS,
                            FILE_ATTRIBUTE_NORMAL, nullptr);
  if (file != INVALID_HANDLE_VALUE) {
    MINIDUMP_EXCEPTION_INFORMATION exception{GetCurrentThreadId(), info, FALSE};
    MiniDumpWriteDump(GetCurrentProcess(), GetCurrentProcessId(), file, MiniDumpNormal, &exception, nullptr,
                      nullptr);
    CloseHandle(file);
  }
  return EXCEPTION_CONTINUE_SEARCH;
}

}  // namespace

void InstallCrashReport() { SetUnhandledExceptionFilter(OnCrash); }
