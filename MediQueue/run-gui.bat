@echo off
setlocal
cd /d "%~dp0"
set FX_VER=25
set FX_DIR=lib\javafx

rem ---- First run only: download JavaFX (it is not included with the JDK) ----
if not exist "%FX_DIR%\javafx-controls-%FX_VER%-win.jar" (
  echo Downloading JavaFX %FX_VER% - first run only...
  if not exist "%FX_DIR%" mkdir "%FX_DIR%"
  for %%M in (base graphics controls) do (
    curl.exe -fL -o "%FX_DIR%\javafx-%%M-%FX_VER%-win.jar" "https://repo1.maven.org/maven2/org/openjfx/javafx-%%M/%FX_VER%/javafx-%%M-%FX_VER%-win.jar"
    if errorlevel 1 (
      echo Download of javafx-%%M failed. Check your internet connection.
      del "%FX_DIR%\javafx-%%M-%FX_VER%-win.jar" 2>nul
      pause
      exit /b 1
    )
  )
)

rem ---- Compile ----
if not exist bin\UI mkdir bin\UI
javac -encoding UTF-8 -d bin -cp "mysql-connector-j-26.10.0.jar" --module-path "%FX_DIR%" --add-modules javafx.controls src\Main.java src\MainApp.java src\Dao\*.java src\Model\*.java src\Services\*.java src\Util\*.java src\UI\*.java
if errorlevel 1 (
  echo Compilation failed.
  pause
  exit /b 1
)
copy /y src\UI\kiosk.css bin\UI\kiosk.css >nul

rem ---- Run the kiosk ----
java --module-path "%FX_DIR%" --add-modules javafx.controls --enable-native-access=javafx.graphics -cp "bin;mysql-connector-j-26.10.0.jar" MainApp
