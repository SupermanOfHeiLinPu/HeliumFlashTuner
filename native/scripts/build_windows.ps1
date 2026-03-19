# ---------------------------------------------------------------------------
# Build the native JUCE tuner DLL for Windows (x64)
#
# Prerequisites:
#   - Visual Studio 2022 (MSVC) or later with C++ Desktop workload
#   - CMake 3.22+ (added to PATH or installed with Visual Studio)
#   - JUCE 8.x cloned into native/JUCE  (or set $env:JUCE_PATH)
#
# Run from the repository root or from the native/scripts directory:
#   powershell -ExecutionPolicy Bypass -File native/scripts/build_windows.ps1
# ---------------------------------------------------------------------------

$ErrorActionPreference = 'Stop'

$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$NativeDir   = Split-Path -Parent $ScriptDir
$BuildDir    = Join-Path $NativeDir 'build\windows'

# Resolve JUCE path
$JucePath = if ($env:JUCE_PATH) { $env:JUCE_PATH } else { Join-Path $NativeDir 'JUCE' }

if (-not (Test-Path (Join-Path $JucePath 'CMakeLists.txt'))) {
    Write-Error @"
JUCE not found at '$JucePath'.
Please clone JUCE 8.x into native\JUCE  or set the JUCE_PATH environment variable:
  git clone --depth 1 --branch 8.0.12 https://github.com/juce-framework/JUCE.git native\JUCE
"@
    exit 1
}

Write-Host "==> Creating build directory: $BuildDir" -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null

Write-Host "==> Configuring with CMake (Release / x64) ..." -ForegroundColor Cyan
$cmakeArgs = @(
    $NativeDir,
    "-B", $BuildDir,
    "-G", "Visual Studio 17 2022",
    "-A", "x64",
    "-DCMAKE_BUILD_TYPE=Release",
    "-DJUCE_PATH=$JucePath"
)
& cmake @cmakeArgs
if ($LASTEXITCODE -ne 0) { Write-Error "CMake configure failed."; exit $LASTEXITCODE }

Write-Host "==> Building Release ..." -ForegroundColor Cyan
& cmake --build $BuildDir --config Release --parallel
if ($LASTEXITCODE -ne 0) { Write-Error "CMake build failed."; exit $LASTEXITCODE }

$DllPath = Join-Path $BuildDir "Release\helium_flash_tuner.dll"
Write-Host ""
Write-Host "✓ DLL built: $DllPath" -ForegroundColor Green
Write-Host ""
Write-Host "Copy it next to the Flutter Windows executable:" -ForegroundColor Yellow
Write-Host "  Copy-Item '$DllPath' '<flutter_app>\build\windows\x64\runner\Release\'" -ForegroundColor Yellow
Write-Host ""
Write-Host "Or let the install step handle it:" -ForegroundColor Yellow
Write-Host "  cmake --install $BuildDir --config Release" -ForegroundColor Yellow
