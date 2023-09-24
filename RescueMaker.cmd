@ECHO OFF
:: Only one instance allowed at a time
SET "TitleName=RescueMaker"
TASKLIST /V /NH /FI "imagename eq cmd.exe"|FIND /I /C "%TitleName%">nul
IF NOT %errorlevel%==1 (ECHO ERROR: & ECHO RescueMaker is already open!) |MSG * & EXIT /b
TITLE %TitleName%
:: Ask for Admin rights
>nul 2>&1 reg add hkcu\software\classes\.RescueMaker\shell\runas\command /f /ve /d "cmd /x /d /r set \"f0=%%2\"& call \"%%2\" %%3"& set _= %*
>nul 2>&1 fltmc|| if "%f0%" neq "%~f0" (cd.>"%ProgramData%\runas.RescueMaker" & start "%~n0" /high "%ProgramData%\runas.RescueMaker" "%~f0" "%_:"=""%" & exit /b)
>nul 2>&1 reg delete hkcu\software\classes\.RescueMaker\ /f &>nul 2>&1 del %ProgramData%\runas.RescueMaker /f /q
:: Check system - Win11/10 Supported - Both show up as 10
FOR /F "usebackq skip=2 tokens=3-4" %%i IN (`REG QUERY "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v ProductName 2^>nul`) DO IF NOT "%%i %%j"=="Windows 10" ECHO. & ECHO Unsupported system detected. & ECHO. & PAUSE & EXIT
:: Copy self to %ProgramData% and run from there (cleanup temp files and self delete at end of script)
CD /D %~dp0
IF NOT "%~f0" EQU "%ProgramData%\%~nx0" (
COPY /Y "%~f0" "%ProgramData%">nul
START "" "%ProgramData%\%~nx0" %*
EXIT /b
)
:: Center window
>nul 2>&1 POWERSHELL -nop -ep Bypass -c "$w=Add-Type -Name WAPI -PassThru -MemberDefinition '[DllImport(\"user32.dll\")]public static extern void SetProcessDPIAware();[DllImport(\"shcore.dll\")]public static extern void SetProcessDpiAwareness(int value);[DllImport(\"kernel32.dll\")]public static extern IntPtr GetConsoleWindow();[DllImport(\"user32.dll\")]public static extern void GetWindowRect(IntPtr hwnd, int[] rect);[DllImport(\"user32.dll\")]public static extern void GetClientRect(IntPtr hwnd, int[] rect);[DllImport(\"user32.dll\")]public static extern void GetMonitorInfoW(IntPtr hMonitor, int[] lpmi);[DllImport(\"user32.dll\")]public static extern IntPtr MonitorFromWindow(IntPtr hwnd, int dwFlags);[DllImport(\"user32.dll\")]public static extern int SetWindowPos(IntPtr hwnd, IntPtr hwndAfterZ, int x, int y, int w, int h, int flags);';$PROCESS_PER_MONITOR_DPI_AWARE=2;try {$w::SetProcessDpiAwareness($PROCESS_PER_MONITOR_DPI_AWARE)} catch {$w::SetProcessDPIAware()}$hwnd=$w::GetConsoleWindow();$moninf=[int[]]::new(10);$moninf[0]=40;$MONITOR_DEFAULTTONEAREST=2;$w::GetMonitorInfoW($w::MonitorFromWindow($hwnd, $MONITOR_DEFAULTTONEAREST), $moninf);$monwidth=$moninf[7] - $moninf[5];$monheight=$moninf[8] - $moninf[6];$wrect=[int[]]::new(4);$w::GetWindowRect($hwnd, $wrect);$winwidth=$wrect[2] - $wrect[0];$winheight=$wrect[3] - $wrect[1];$x=[int][math]::Round($moninf[5] + $monwidth / 2 - $winwidth / 2);$y=[int][math]::Round($moninf[6] + $monheight / 2 - $winheight / 2);$SWP_NOSIZE=0x0001;$SWP_NOZORDER=0x0004;exit [int]($w::SetWindowPos($hwnd, [IntPtr]::Zero, $x, $y, 0, 0, $SWP_NOSIZE -bOr $SWP_NOZORDER) -eq 0)"
:: Create cache folders
IF EXIST "%~dp0RescueMaker" RD "%~dp0RescueMaker" /S /Q>nul
MD "%~dp0RescueMaker\Junkbin">nul
MD "%~dp0RescueMaker\Root">nul
:: Get 7-Zip - Wimlib-ImageX - SetACL(This may be needed for some apps)
ECHO. & ECHO Getting Utilities...
PUSHD "%~dp0RescueMaker" & PUSHD "%~dp0RescueMaker\Junkbin"
POWERSHELL -nop -c "Invoke-WebRequest -Uri https://www.7-zip.org/a/7zr.exe -o '7zr.exe'"; "Invoke-WebRequest -Uri https://www.7-zip.org/a/7z2300-extra.7z -o '7zExtra.7z'"; "Invoke-WebRequest -Uri https://wimlib.net/downloads/wimlib-1.14.1-windows-x86_64-bin.zip -o 'wimlib.zip'"; "Invoke-WebRequest -Uri https://helgeklein.com/downloads/SetACL/current/SetACL%%203.1.2%%20`(executable%%20version`).zip -o 'SetACL.zip'"
7zr.exe e -y 7zExtra.7z>nul & 7za.exe e -y wimlib.zip libwim-15.dll -r -o..>nul & 7za.exe e -y wimlib.zip wimlib-imagex.exe -r -o..>nul & 7za.exe e -y SetACL.zip "SetACL (executable version)\64 bit\SetACL.exe" -r -o..>nul & POPD
:: Find a recovery partition
ECHO.&ECHO Creating Rescue Media from HostOS...&ECHO.
FOR /F "usebackq delims=" %%a in (`mountvol^|find "\\"`) do (
SETLOCAL ENABLEDELAYEDEXPANSION
CALL :MOUNTPOINT
MOUNTVOL !M1!: %%a>nul
IF EXIST !M1!:\Recovery\WindowsRE\WinRE.wim (
wimlib-imagex extract !M1!:\Recovery\WindowsRE\WinRE.wim 1 "\Windows" --no-acls --no-attributes --dest-dir="%~dp0RescueMaker\Root"
wimlib-imagex extract !M1!:\Recovery\WindowsRE\WinRE.wim 1 "\Program Files" --no-acls --no-attributes --dest-dir="%~dp0RescueMaker\Root"
wimlib-imagex extract !M1!:\Recovery\WindowsRE\WinRE.wim 1 "\Program Files (x86)" --no-acls --no-attributes --dest-dir="%~dp0RescueMaker\Root"
wimlib-imagex extract !M1!:\Recovery\WindowsRE\WinRE.wim 1 "\ProgramData" --no-acls --no-attributes --dest-dir="%~dp0RescueMaker\Root"
wimlib-imagex extract !M1!:\Recovery\WindowsRE\WinRE.wim 1 "\Users" --no-acls --no-attributes --dest-dir="%~dp0RescueMaker\Root"
GOTO EXTRACTED
)
:EXTRACTED
MOUNTVOL !M1!: /D>nul
)
IF NOT EXIST "%~dp0RescueMaker\Root\Windows\*" (ENDLOCAL &ECHO.&ECHO WARNING - No recovery partition exists!! ^(Try using - reagentc /enable - before proceeding^)&ECHO.&ECHO Aborting process and cleaning up cache folders..&ECHO.&GOTO CLEANUPANDEXIT)
:: Configure Rescue Disk
ECHO.&ECHO Adding Tools...&ECHO.
CALL :GETUNLOCKER
COPY /Y "%~dp0RescueMaker\WLU.exe" "%~dp0RescueMaker\Root\Windows\System32">nul
COPY /Y "%SystemDrive%\Windows\System32\offreg.dll" "%~dp0RescueMaker\Root\Windows\System32">nul
CALL :SETSTARTUP
CALL :BURNMENU
ECHO Media Creation Complete! &ECHO.
:CLEANUPANDEXIT
:: Remove cache folders
POPD&>nul 2>&1 RD "%~dp0RescueMaker" /S /Q
PAUSE
:: Self delete and exit
(GOTO) 2>nul & del "%~f0">nul&EXIT
:BURNMENU
SET "USBDISK="&SET "EXISTS="&SET "DTYPE2="&SET "L1="&SET "L2="&SET "LASTCHECK="&DEL "%~dp0RescueMaker\*.diskpart" /F /Q>nul
CLS
ECHO Create Rescue Media (USB Devices only)
ECHO ===================================================
CALL :LISTDISKS
ECHO Press ENTER to refresh disk list&ECHO.
SET /P USBDISK="Enter the USB DISK # you would like to use (X to Exit): "
IF "%USBDISK%"=="" GOTO BURNMENU
IF "%USBDISK%"=="x" SET "USBDISK=X"
IF "%USBDISK%"=="X" ECHO.&ECHO Aborting media creation and cleaning up cache folders...&ECHO.&GOTO CLEANUPANDEXIT
CALL :DISKEXIST %USBDISK% EXISTS
IF %EXISTS%==1 ECHO.&ECHO Disk %USBDISK% doesn't exist! &ECHO.&PAUSE&GOTO BURNMENU
CALL :CHECKDISK %USBDISK%
SETLOCAL ENABLEDELAYEDEXPANSION
CALL :GETDISKTYPE DTYPE2
IF NOT "!DTYPE2!"=="USB" DEL "%~dp0RescueMaker\currentdisk.diskpart" /F /Q>nul&SET "USBDISK="&ECHO.&ECHO The selected disk is not a USB device. Only USB drives are supported at this time.&ECHO.&PAUSE&ECHO.&GOTO BURNMENU
CALL :VERIFYDELETE %USBDISK% LASTCHECK
IF "!LASTCHECK!"=="N" GOTO BURNMENU
CALL :AVAILABLEDRIVELETTERS
CALL :CONFIGDISKPART %USBDISK% !L1! !L2!
ECHO Formatting USB...&ECHO.
>nul 2>&1 DISKPART /S "%~dp0\RescueMaker\Clean.diskpart"
>nul 2>&1 DISKPART /S "%~dp0\RescueMaker\Scrubber.diskpart"
>nul 2>&1 DISKPART /S "%~dp0\RescueMaker\Clean.diskpart"
>nul 2>&1 DISKPART /S "%~dp0\RescueMaker\Attrib.diskpart"
>nul 2>&1 DISKPART /S "%~dp0\RescueMaker\Convert.diskpart"
>nul 2>&1 DISKPART /S "%~dp0\RescueMaker\InitData.diskpart"
>nul 2>&1 DISKPART /S "%~dp0\RescueMaker\InitBoot.diskpart"
DEL "%~dp0RescueMaker\*.diskpart" /F /Q
ECHO Copying Files, Please Wait...&ECHO.
>nul 2>&1 XCOPY "%~dp0RescueMaker\Root\" "!L1!:\" /E /H /C /I /Y
BCDBOOT !L1!:\Windows /s !L2!: /f ALL /d /addlast
ENDLOCAL&ECHO.
EXIT /b
:LISTDISKS
(ECHO lis dis)>"%~dp0RescueMaker\list.diskpart"&ECHO.
FOR /F "usebackq skip=2 tokens=1,2,4,5" %%a in (`DISKPART /S "%~dp0RescueMaker\list.diskpart" ^| FIND "Disk"`) DO (
CALL :CHECKDISK %%b
CALL :GETDISKNAME DNAME
CALL :GETDISKTYPE DTYPE
SETLOCAL ENABLEDELAYEDEXPANSION
ECHO    Disk #^[%%b^]-^[%%c %%d^]-^[!DTYPE:USB=USB~!^]-^[!DNAME!^]
ENDLOCAL
DEL "%~dp0RescueMaker\currentdisk.diskpart" /F /Q>nul
)
DEL "%~dp0RescueMaker\list.diskpart" /F /Q&ECHO.
EXIT /b
:GETDISKNAME
FOR /F "usebackq skip=7 delims=" %%a in (`DISKPART /S "%~dp0RescueMaker\currentdisk.diskpart"`) DO (
SET "%1=%%a"
EXIT /B
)
EXIT /b
:GETDISKTYPE
FOR /F "usebackq tokens=3" %%a in (`DISKPART /S "%~dp0RescueMaker\currentdisk.diskpart" ^| FIND "Type"`) DO (
SET "%1=%%a"
EXIT /b
)
EXIT /b
:CHECKDISK
(ECHO SEL DIS %1&ECHO DETAIL DISK)>"%~dp0RescueMaker\currentdisk.diskpart"
EXIT/b
:VERIFYDELETE
(ECHO lis dis)>"%~dp0RescueMaker\list.diskpart"&ECHO.
FOR /F "usebackq skip=2 tokens=1,2,4,5" %%a in (`DISKPART /S "%~dp0RescueMaker\list.diskpart" ^| FIND "Disk"`) DO (
IF %1==%%b (
CALL :CHECKDISK %%b
CALL :GETDISKNAME DNAME
CALL :GETDISKTYPE DTYPE
SETLOCAL ENABLEDELAYEDEXPANSION
ECHO    Disk #^[%%b^]-^[%%c %%d^]-^[!DTYPE:USB=USB~!^]-^[!DNAME!^] will be completely erased.&ECHO.
ENDLOCAL
CHOICE /C YN /N /M "    Are you sure? This process is irreversable. [Y/N]: "
IF !errorlevel!==2 SET "%2=N"
DEL "%~dp0RescueMaker\currentdisk.diskpart" /F /Q>nul
DEL "%~dp0RescueMaker\list.diskpart" /F /Q&ECHO.
EXIT /b
)
)
EXIT /b
:CONFIGDISKPART
(ECHO Sel Dis %1 & ECHO clean & ECHO Exit)>"%~dp0\RescueMaker\Clean.diskpart"
(ECHO Sel Dis %1 & ECHO attribute disk clear readonly & ECHO Exit)>"%~dp0\RescueMaker\Attrib.diskpart"
(ECHO Sel Dis %1 & ECHO cre par pri & ECHO format quick fs=NTFS label=scrubber & ECHO Exit)>"%~dp0\RescueMaker\Scrubber.diskpart"
(ECHO Sel Dis %1 & ECHO convert gpt & ECHO Exit)>"%~dp0\RescueMaker\Convert.diskpart"
(ECHO Sel Dis %1 & ECHO cre par pri & ECHO shrink minimum=200 & ECHO format quick fs=ntfs label="RescueDisk" & ECHO assign letter=%2 &ECHO Exit)>"%~dp0\RescueMaker\InitData.diskpart"
(ECHO Sel Dis %1 & ECHO cre par efi & ECHO format quick fs=fat32 label="Boot" & ECHO assign letter=%3 & ECHO Exit)>"%~dp0\RescueMaker\InitBoot.diskpart"
EXIT /b
:SETSTARTUP
(
ECHO [LaunchApp]
ECHO AppPath=X:\Windows\System32\WLU.exe
)>"%~dp0RescueMaker\Root\Windows\System32\winpeshl.ini"
EXIT /b
:GETUNLOCKER
PUSHD "%~dp0RescueMaker\Junkbin"
POWERSHELL -nop -c "Invoke-WebRequest -Uri https://github.com/illsk1lls/RescueMaker/raw/main/Tools/WindowsLoginUnlocker/WLU.7z -o 'WLU.7z'"
7za.exe e -y WLU.7z -o..>nul&POPD
EXIT /b
:AVAILABLEDRIVELETTERS
SET LT=1
FOR %%a IN (D E F G H I J K L M N O P Q R S T U V W X Y Z) DO (
IF NOT EXIST %%a:\* (
SET L!LT!=%%a
SET /A LT+=1
)
IF !LT! GEQ 3 ENDLOCAL &EXIT /b
)
EXIT /b
:DISKEXIST
>nul 2>&1 POWERSHELL -nop -c "Get-Disk %1"
SET %2=%errorlevel%
EXIT /b
:MOUNTPOINT
SET MT=1
FOR %%a IN (Z Y X W V U T S R Q P O N M L K J I H G F E D) DO (
IF NOT EXIST %%a:\* (
SET M!MT!=%%a
SET /A MT+=1
)
IF !MT! GEQ 2 ENDLOCAL &EXIT /b
)
EXIT /b