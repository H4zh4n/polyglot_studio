@echo off
setlocal enabledelayedexpansion

:: Navigate to project root
cd /d "%~dp0"

echo ================================================================
echo              Polyglot Studio - Automated Build Script           
echo ================================================================
echo.

:: 1. Check for Flutter
where flutter >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Flutter is not found in your PATH. Please install Flutter or add it to PATH.
    pause
    exit /b 1
)

:: 2. Extract version from pubspec.yaml (extracts X.Y.Z from version: X.Y.Z+N)
set "APP_VERSION=1.0.0"
for /f "tokens=2 delims=: " %%a in ('findstr /b /c:"version:" pubspec.yaml') do (
    for /f "tokens=1 delims=+" %%b in ("%%a") do (
        set "APP_VERSION=%%b"
    )
)

echo [*] Detected App Version: v%APP_VERSION%
echo.

:: Parse build targets (default: all)
set BUILD_ANDROID=1
set BUILD_WINDOWS=1

if /i "%~1"=="android" (
    set BUILD_ANDROID=1
    set BUILD_WINDOWS=0
) else if /i "%~1"=="windows" (
    set BUILD_ANDROID=0
    set BUILD_WINDOWS=1
) else if /i "%~1"=="apk" (
    set BUILD_ANDROID=1
    set BUILD_WINDOWS=0
) else if /i "%~1"=="win" (
    set BUILD_ANDROID=0
    set BUILD_WINDOWS=1
)

:: Create dist directory for final releases
set "DIST_DIR=%~dp0dist"
if not exist "%DIST_DIR%" (
    mkdir "%DIST_DIR%"
)

:: ================================================================
:: Android Build
:: ================================================================
if "%BUILD_ANDROID%"=="1" (
    echo ----------------------------------------------------------------
    echo  Building Android Release APK...
    echo ----------------------------------------------------------------
    
    call flutter build apk --release
    if %errorlevel% neq 0 (
        echo [ERROR] Android build failed!
        if "%~1"=="" goto windows_step
        pause
        exit /b %errorlevel%
    )
    
    set "SRC_APK=%~dp0build\app\outputs\flutter-apk\app-release.apk"
    set "DEST_APK=%DIST_DIR%\PolyglotStudio_v%APP_VERSION%_android.apk"
    
    if exist "!SRC_APK!" (
        copy /y "!SRC_APK!" "!DEST_APK!" >nul
        echo [SUCCESS] Android APK created:
        echo           !DEST_APK!
    ) else (
        echo [WARNING] Expected APK at !SRC_APK! not found!
    )
    echo.
)

:windows_step
:: ================================================================
:: Windows Build
:: ================================================================
if "%BUILD_WINDOWS%"=="1" (
    echo ----------------------------------------------------------------
    echo  Building Windows Release...
    echo ----------------------------------------------------------------
    
    call flutter build windows --release
    if %errorlevel% neq 0 (
        echo [ERROR] Windows build failed!
        pause
        exit /b %errorlevel%
    )
    
    :: Locate Windows runner release output directory
    set "WIN_RELEASE_DIR="
    if exist "%~dp0build\windows\x64\runner\Release" (
        set "WIN_RELEASE_DIR=%~dp0build\windows\x64\runner\Release"
    ) else if exist "%~dp0build\windows\runner\Release" (
        set "WIN_RELEASE_DIR=%~dp0build\windows\runner\Release"
    )
    
    if "!WIN_RELEASE_DIR!"=="" (
        echo [ERROR] Windows build output directory could not be found!
        pause
        exit /b 1
    )
    
    :: Copy Visual C++ redistributable DLLs into the release directory
    set "REDIST_DIR=%~dp0windows\redist"
    if exist "!REDIST_DIR!" (
        echo [*] Copying VC runtime DLLs from windows\redist...
        if exist "!REDIST_DIR!\msvcp140.dll" copy /y "!REDIST_DIR!\msvcp140.dll" "!WIN_RELEASE_DIR!\" >nul
        if exist "!REDIST_DIR!\vcruntime140.dll" copy /y "!REDIST_DIR!\vcruntime140.dll" "!WIN_RELEASE_DIR!\" >nul
        if exist "!REDIST_DIR!\vcruntime140_1.dll" copy /y "!REDIST_DIR!\vcruntime140_1.dll" "!WIN_RELEASE_DIR!\" >nul
    ) else (
        echo [WARNING] windows\redist directory not found. Skipping VC runtime copy.
    )

    :: Ensure executable is named PolyglotStudio.exe (if needed)
    if exist "!WIN_RELEASE_DIR!\polyglot.exe" (
        if not exist "!WIN_RELEASE_DIR!\PolyglotStudio.exe" (
            ren "!WIN_RELEASE_DIR!\polyglot.exe" "PolyglotStudio.exe"
        )
    )

    :: Stage files inside folder named PolyglotStudio_vX.X.X_windows
    set "STAGE_ROOT=%~dp0build\zip_staging"
    set "BUNDLE_NAME=PolyglotStudio_v%APP_VERSION%_windows"
    set "BUNDLE_DIR=!STAGE_ROOT!\!BUNDLE_NAME!"
    
    if exist "!STAGE_ROOT!" rd /s /q "!STAGE_ROOT!"
    mkdir "!BUNDLE_DIR!"
    
    echo [*] Staging Windows package in: !BUNDLE_NAME!...
    xcopy /e /i /y "!WIN_RELEASE_DIR!\*" "!BUNDLE_DIR!\" >nul
    
    :: Create Windows Zip Archive
    set "DEST_ZIP=%DIST_DIR%\!BUNDLE_NAME!.zip"
    if exist "!DEST_ZIP!" del /f /q "!DEST_ZIP!"
    
    echo [*] Compressing into !BUNDLE_NAME!.zip...
    powershell -NoProfile -Command "Compress-Archive -Path '!BUNDLE_DIR!' -DestinationPath '!DEST_ZIP!' -Force"
    
    :: Cleanup staging folder
    if exist "!STAGE_ROOT!" rd /s /q "!STAGE_ROOT!"
    
    echo [SUCCESS] Windows ZIP archive created:
    echo           !DEST_ZIP!
    echo.
)

:: ================================================================
:: Summary
:: ================================================================
echo ================================================================
echo                       Build Completed!                          
echo ================================================================
echo Release artifacts located in:
echo   %DIST_DIR%
echo.
if "%BUILD_ANDROID%"=="1" (
    if exist "%DIST_DIR%\PolyglotStudio_v%APP_VERSION%_android.apk" (
        echo   - PolyglotStudio_v%APP_VERSION%_android.apk
    )
)
if "%BUILD_WINDOWS%"=="1" (
    if exist "%DIST_DIR%\PolyglotStudio_v%APP_VERSION%_windows.zip" (
        echo   - PolyglotStudio_v%APP_VERSION%_windows.zip
    )
)
echo ================================================================
echo.

if "%~1"=="" (
    echo Press any key to exit...
    pause >nul
)
