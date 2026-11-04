@echo off
setlocal
cd /d "%~dp0"
set FX_DIR=lib\javafx

call fetch-javafx.bat
if errorlevel 1 (
  pause
  exit /b 1
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
