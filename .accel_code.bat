@echo off
for %%I in (.) do set CurrDir=%%~nxI
if "%CurrDir%"=="my_toolbox" cd ..
code .
exit