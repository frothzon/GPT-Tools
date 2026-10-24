@echo off
setlocal
set "PYTHONPATH=%~dp0src;%PYTHONPATH%"
set "PYTHONUTF8=1"
py -3 -m gmtool %*
exit /b %ERRORLEVEL%
