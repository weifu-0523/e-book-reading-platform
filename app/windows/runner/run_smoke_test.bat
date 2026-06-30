@echo off
REM run_smoke_test.bat
REM
REM Compiles and runs test_main.cpp against deep_link_parser.cpp using
REM MSVC (cl.exe). The project lives at a path with Chinese characters
REM which break the MSVC compiler driver, so the sources are copied to
REM an ASCII working directory (C:\dev\zhiyue-smoke) before building.
REM
REM Exit codes:
REM   0  - smoke test compiled and all asserts passed
REM   1  - compile failed, or one or more asserts failed
REM   99 - vcvars64.bat could not be located (MSVC not installed)

setlocal enabledelayedexpansion

set SMOKE_DIR=C:\dev\zhiyue-smoke
set SOURCE=%~dp0

if not exist "%SMOKE_DIR%" mkdir "%SMOKE_DIR%"

copy /Y "%SOURCE%deep_link_parser.h"   "%SMOKE_DIR%\" >nul
if errorlevel 1 (
  echo ERROR: failed to copy deep_link_parser.h
  exit /b 1
)
copy /Y "%SOURCE%deep_link_parser.cpp" "%SMOKE_DIR%\" >nul
if errorlevel 1 (
  echo ERROR: failed to copy deep_link_parser.cpp
  exit /b 1
)
copy /Y "%SOURCE%test_main.cpp"        "%SMOKE_DIR%\" >nul
if errorlevel 1 (
  echo ERROR: failed to copy test_main.cpp
  exit /b 1
)

cd /D "%SMOKE_DIR%"

REM Locate vcvars64.bat across common Visual Studio install layouts.
set VCVARS=
for %%P in (
  "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
  "C:\Program Files\Microsoft Visual Studio\2022\Professional\VC\Auxiliary\Build\vcvars64.bat"
  "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvars64.bat"
  "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
  "C:\Program Files\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvars64.bat"
  "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
) do (
  if exist %%P set VCVARS=%%~P
)

if "%VCVARS%"=="" (
  echo ERROR: vcvars64.bat not found. Install Visual Studio 2019/2022 or the
  echo        Visual Studio Build Tools for C++, then re-run.
  exit /b 99
)

echo Setting up MSVC environment: %VCVARS%
call "%VCVARS%" >nul
if errorlevel 1 (
  echo ERROR: vcvars64.bat failed to initialise.
  exit /b 1
)

echo Compiling test_main.cpp + deep_link_parser.cpp ...
REM Output name is "deep_link_smoke.exe" (not "test.exe") to avoid a
REM name collision with MSYS' test.exe that lives on PATH and would
REM otherwise shadow our local binary once vcvars64 reorders PATH.
cl.exe /EHsc /nologo /W3 /Fe:deep_link_smoke.exe test_main.cpp deep_link_parser.cpp
if errorlevel 1 (
  echo COMPILE FAILED.
  exit /b 1
)

echo Running smoke test ...
.\deep_link_smoke.exe
if errorlevel 1 (
  echo TEST FAILED.
  exit /b 1
)

echo SMOKE TEST PASSED.
exit /b 0
