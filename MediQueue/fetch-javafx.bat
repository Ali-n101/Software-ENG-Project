@echo off
rem Downloads JavaFX (not bundled with the JDK) into MediQueue\lib\javafx. Safe to run many times.
setlocal
cd /d "%~dp0"
set FX_VER=25
set FX_DIR=lib\javafx
if exist "%FX_DIR%\javafx-controls-%FX_VER%-win.jar" exit /b 0
echo Downloading JavaFX %FX_VER% - first time only...
if not exist "%FX_DIR%" mkdir "%FX_DIR%"
for %%M in (base graphics controls) do (
  curl.exe -fL -o "%FX_DIR%\javafx-%%M-%FX_VER%-win.jar" "https://repo1.maven.org/maven2/org/openjfx/javafx-%%M/%FX_VER%/javafx-%%M-%FX_VER%-win.jar"
  if errorlevel 1 (
    echo Download of javafx-%%M failed. Check your internet connection.
    del "%FX_DIR%\javafx-%%M-%FX_VER%-win.jar" 2>nul
    exit /b 1
  )
)
echo JavaFX ready.
exit /b 0
