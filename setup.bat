@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul
cd /d "%~dp0"
echo ==================================================
echo   MediQueue - one-time setup for team members
echo ==================================================
echo.

where winget >nul 2>nul
if errorlevel 1 (
  set NO_WINGET=1
  echo [!] winget is not available. Missing programs must be installed by hand - see README.md
)

rem ---------------- 1. Java JDK 23+ ----------------
echo [1/4] Checking Java JDK...
set JAVA_OK=0
set JMAJOR=0
where javac >nul 2>nul
if not errorlevel 1 (
  for /f "tokens=2 delims==" %%V in ('java -XshowSettings:properties -version 2^>^&1 ^| findstr /c:"java.specification.version"') do set JV=%%V
  if defined JV set JV=!JV: =!
  for /f "delims=." %%M in ("!JV!") do set JMAJOR=%%M
  if !JMAJOR! GEQ 23 set JAVA_OK=1
)
if "!JAVA_OK!"=="1" (
  echo       OK - Java !JMAJOR! found.
) else (
  echo       Java JDK 23 or newer was not found. Installing Temurin JDK 25...
  if defined NO_WINGET (
    echo       Please install a JDK 23+ from https://adoptium.net and run setup.bat again.
  ) else (
    winget install -e --id EclipseAdoptium.Temurin.25.JDK --accept-package-agreements --accept-source-agreements
    set NEED_RESTART=1
  )
)
echo.

rem ---------------- 2. VS Code Java extension ----------------
echo [2/4] Checking VS Code Java extension...
where code >nul 2>nul
if errorlevel 1 (
  echo       VS Code command not found - skipping. VS Code will suggest the extension when you open the project.
) else (
  call code --install-extension vscjava.vscode-java-pack >nul 2>nul
  echo       OK - Extension Pack for Java installed.
)
echo.

rem ---------------- 3. MySQL ----------------
echo [3/4] Checking MySQL...
set MYSQL=
where mysql >nul 2>nul
if not errorlevel 1 set MYSQL=mysql
if not defined MYSQL (
  for /d %%D in ("C:\Program Files\MySQL\MySQL Server *") do if exist "%%D\bin\mysql.exe" set MYSQL="%%D\bin\mysql.exe"
)
if not defined MYSQL (
  echo       MySQL Server was not found.
  if defined NO_WINGET (
    echo       Please install MySQL 8 from https://dev.mysql.com/downloads/installer/
  ) else (
    echo       Installing MySQL Server...
    winget install -e --id Oracle.MySQL --accept-package-agreements --accept-source-agreements
  )
  echo.
  echo       IMPORTANT: finish the MySQL setup ^(MySQL Configurator^), choose a root password,
  echo       then run setup.bat again to create the database.
  set NEED_RESTART=1
) else (
  echo       OK - MySQL found.
  echo.
  echo       Create the mediqueue database now?
  echo       WARNING: this deletes any existing mediqueue database and its bookings.
  set /p MAKEDB="      Type Y to continue, anything else to skip: "
  if /i "!MAKEDB!"=="Y" (
    echo       Enter your MySQL root password when asked:
    type "database\schema.sql" "database\seed.sql" 2>nul | !MYSQL! -u root -p --default-character-set=utf8mb4
    if errorlevel 1 (
      echo       [X] Database setup failed. Check the password and that MySQL is running.
    ) else (
      echo       OK - database created with test data.
    )
  ) else (
    echo       Skipped.
  )
)
echo.

rem ---------------- 4. JavaFX ----------------
echo [4/4] Downloading JavaFX...
call MediQueue\fetch-javafx.bat
echo.

echo ==================================================
if defined NEED_RESTART (
  echo   Some programs were just installed.
  echo   Close this window, finish any installer, then run setup.bat again.
) else (
  echo   Setup complete!  Start the kiosk with:
  echo      MediQueue\run-gui.bat
)
echo ==================================================
pause
