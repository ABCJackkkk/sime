@echo off
setlocal enabledelayedexpansion

cd /d "D:\AR\love_sim"

echo ========================================
echo   Building Android APK...
echo ========================================
echo.

set JAVA_HOME=D:\and\jbr
set ANDROID_SDK_ROOT=D:\ar\android_sdk
set ANDROID_HOME=D:\ar\android_sdk
set GRADLE_USER_HOME=D:\ar\gradle_cache
set PUB_CACHE=D:\ar\pub_cache
set GRADLE_OPTS=-Dgradle.user.home=D:\ar\gradle_cache
set PATH=%JAVA_HOME%\bin;%PATH%

echo [1/3] Cleaning old build...
if exist build (
    rmdir /s /q build
)
echo Done.
echo.

echo [2/3] Building APK (debug version)...
echo This may take a few minutes, please wait...
echo.

call "D:\AR\flutter_sdk\flutter\bin\flutter.bat" build apk --debug
set BUILD_EXIT=%ERRORLEVEL%

echo.
echo ========================================
if %BUILD_EXIT%==0 (
    echo   Build Success!
    echo.
    echo   APK location:
    echo   D:\AR\love_sim\build\app\outputs\flutter-apk\app-debug.apk
) else (
    echo   Build FAILED, error code: %BUILD_EXIT%
)
echo ========================================
echo.
pause
