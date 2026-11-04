@echo off
cd /d "%~dp0"
if not exist bin mkdir bin
javac -encoding UTF-8 -d bin -cp "mysql-connector-j-26.10.0.jar" src\Main.java src\Dao\*.java src\Model\*.java src\Services\*.java src\Util\*.java
if errorlevel 1 (
  echo Compilation failed.
  pause
  exit /b 1
)
java -cp "bin;mysql-connector-j-26.10.0.jar" Main
