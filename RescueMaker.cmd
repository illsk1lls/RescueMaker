@ECHO OFF
REM Only one instance allowed at a time
SET "TitleName=RescueMaker"
TASKLIST /V /NH /FI "imagename eq cmd.exe"|FIND /I /C "%TitleName%">nul
IF NOT %errorlevel%==1 (
	POWERSHELL -nop -c "$^={$Notify=[PowerShell]::Create().AddScript({$Audio=New-Object System.Media.SoundPlayer;$Audio.SoundLocation=$env:WinDir + '\Media\Windows Notify System Generic.wav';$Audio.playsync()});$rs=[RunspaceFactory]::CreateRunspace();$rs.ApartmentState="^""STA"^"";$rs.ThreadOptions="^""ReuseThread"^"";$rs.Open();$Notify.Runspace=$rs;$Notify.BeginInvoke()};&$^;$PopUp=New-Object -ComObject Wscript.Shell;$PopUp.Popup("^""RescueMaker is already open!"^"",0,'ERROR:',0x10)">nul&EXIT
)
TITLE %TitleName%
REM Check system - Win11/10 Supported - Both show up as 10
FOR /F "usebackq skip=2 tokens=3-4" %%# IN (`REG QUERY "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v ProductName 2^>nul`) DO (
	IF NOT "%%# %%$"=="Windows 10" (
		ECHO/
		ECHO Unsupported system detected.
		ECHO/
		PAUSE
		EXIT
	)
)
REM Run as Admin, set terminal type, copy self to %ProgramData% and run from there
IF /I NOT "%~dp0" == "%ProgramData%\" (
	>nul 2>&1 REG ADD HKCU\Software\classes\.RescueMaker\shell\runas\command /f /ve /d "CMD /x /d /r SET \"f0=1\"&CALL \"%%2\" %%3"
	CD.>"%ProgramData%\launcher.RescueMaker"
	>nul 2>&1 COPY /Y "%~f0" "%ProgramData%"
	CALL :SETTERMINAL
	>nul 2>&1 FLTMC && (
		TITLE Re-Launching...
		START "" "%ProgramData%\launcher.RescueMaker" "%ProgramData%\%~nx0"
		CALL :RESTORETERMINAL
		>nul 2>&1 REG DELETE HKCU\Software\classes\.RescueMaker\ /F
		>nul 2>&1 DEL "%ProgramData%\launcher.RescueMaker" /F /Q
		EXIT /b
	) || IF NOT "%f0%"=="1" (
		TITLE Re-Launching...
		START "" /high "%ProgramData%\launcher.RescueMaker" "%ProgramData%\%~nx0"
		CALL :RESTORETERMINAL
		>nul 2>&1 REG DELETE HKCU\Software\classes\.RescueMaker\ /F
		>nul 2>&1 DEL "%ProgramData%\launcher.RescueMaker" /F /Q
		EXIT /b
	)
)
REM Center window
>nul 2>&1 POWERSHELL -nop -c "$w=Add-Type -Name WAPI -PassThru -MemberDefinition '[DllImport(\"user32.dll\")]public static extern void SetProcessDPIAware();[DllImport(\"shcore.dll\")]public static extern void SetProcessDpiAwareness(int value);[DllImport(\"kernel32.dll\")]public static extern IntPtr GetConsoleWindow();[DllImport(\"user32.dll\")]public static extern void GetWindowRect(IntPtr hwnd, int[] rect);[DllImport(\"user32.dll\")]public static extern void GetClientRect(IntPtr hwnd, int[] rect);[DllImport(\"user32.dll\")]public static extern void GetMonitorInfoW(IntPtr hMonitor, int[] lpmi);[DllImport(\"user32.dll\")]public static extern IntPtr MonitorFromWindow(IntPtr hwnd, int dwFlags);[DllImport(\"user32.dll\")]public static extern int SetWindowPos(IntPtr hwnd, IntPtr hwndAfterZ, int x, int y, int w, int h, int flags);';$PROCESS_PER_MONITOR_DPI_AWARE=2;try {$w::SetProcessDpiAwareness($PROCESS_PER_MONITOR_DPI_AWARE)} catch {$w::SetProcessDPIAware()}$hwnd=$w::GetConsoleWindow();$moninf=[int[]]::new(10);$moninf[0]=40;$MONITOR_DEFAULTTONEAREST=2;$w::GetMonitorInfoW($w::MonitorFromWindow($hwnd, $MONITOR_DEFAULTTONEAREST), $moninf);$monwidth=$moninf[7] - $moninf[5];$monheight=$moninf[8] - $moninf[6];$wrect=[int[]]::new(4);$w::GetWindowRect($hwnd, $wrect);$winwidth=$wrect[2] - $wrect[0];$winheight=$wrect[3] - $wrect[1];$x=[int][math]::Round($moninf[5] + $monwidth / 2 - $winwidth / 2);$y=[int][math]::Round($moninf[6] + $monheight / 2 - $winheight / 2);$SWP_NOSIZE=0x0001;$SWP_NOZORDER=0x0004;exit [int]($w::SetWindowPos($hwnd, [IntPtr]::Zero, $x, $y, 0, 0, $SWP_NOSIZE -bOr $SWP_NOZORDER) -eq 0)"
REM Create cache folders
ECHO/
ECHO Getting Ready...
IF EXIST "%~dp0RescueMaker" (
	RD "%~dp0RescueMaker" /S /Q>nul
)
MD "%~dp0RescueMaker\Junkbin">nul
MD "%~dp0RescueMaker\Root">nul
REM Get 7-Zip - Wimlib-ImageX - SetACL
CLS
ECHO/
ECHO Getting Utilities...
PUSHD "%~dp0RescueMaker"
PUSHD "%~dp0RescueMaker\Junkbin"
POWERSHELL -nop -c "Start-BitsTransfer -Priority Foreground -Source https://www.7-zip.org/a/7zr.exe -Destination '%~dp0RescueMaker\Junkbin\7zr.exe'"; "Start-BitsTransfer -Priority Foreground -Source https://www.7-zip.org/a/7z2300-extra.7z -Destination '%~dp0RescueMaker\Junkbin\7zExtra.7z'"; "Start-BitsTransfer -Priority Foreground -Source https://wimlib.net/downloads/wimlib-1.14.1-windows-x86_64-bin.zip -Destination '%~dp0RescueMaker\Junkbin\wimlib.zip'"; "Start-BitsTransfer -Priority Foreground -Source https://helgeklein.com/downloads/SetACL/current/SetACL%%203.1.2%%20`(executable%%20version`).zip -Destination '%~dp0RescueMaker\Junkbin\SetACL.zip'"
7zr.exe e -y 7zExtra.7z>nul
7za.exe e -y wimlib.zip libwim-15.dll -r -o..>nul
7za.exe e -y wimlib.zip wimlib-imagex.exe -r -o..>nul
7za.exe e -y SetACL.zip "SetACL (executable version)\64 bit\SetACL.exe" -r -o..>nul
POPD
REM Find a recovery partition
ECHO/
ECHO Creating Rescue Media from HostOS...
ECHO/
SET "NOUNMOUNT="
SET "WinRePath=Recovery\WindowsRE"
FOR /F "usebackq delims=" %%# in (`mountvol^|find "\\"`) do (
	SETLOCAL ENABLEDELAYEDEXPANSION
	CALL :AVAILABLEDRIVELETTERS 1
	MOUNTVOL !L1!: %%#>nul

:EXTRACT
	IF EXIST !L1!:\!WinRePath!\WinRE.wim (
		wimlib-imagex extract !L1!:\!WinRePath!\WinRE.wim 1 "\Windows" --no-acls --no-attributes --dest-dir="%~dp0RescueMaker\Root"
		wimlib-imagex extract !L1!:\!WinRePath!\WinRE.wim 1 "\Program Files" --no-acls --no-attributes --dest-dir="%~dp0RescueMaker\Root"
		wimlib-imagex extract !L1!:\!WinRePath!\WinRE.wim 1 "\Program Files (x86)" --no-acls --no-attributes --dest-dir="%~dp0RescueMaker\Root"
		wimlib-imagex extract !L1!:\!WinRePath!\WinRE.wim 1 "\ProgramData" --no-acls --no-attributes --dest-dir="%~dp0RescueMaker\Root"
		wimlib-imagex extract !L1!:\!WinRePath!\WinRE.wim 1 "\Users" --no-acls --no-attributes --dest-dir="%~dp0RescueMaker\Root"
		GOTO EXTRACTED
	)

:EXTRACTED
	IF "!NOUNMOUNT!"=="" MOUNTVOL !L1!: /D>nul
)
IF NOT EXIST "%~dp0RescueMaker\Root\Windows\*" (
	CALL :FINDRE
	IF "!R1!"=="" (
		ENDLOCAL 
		ECHO WARNING! - No recovery partition detected. ^(Try using - reagentc /enable - before proceeding^)
		ECHO/
		ECHO Aborting process and cleaning up cache folders..
		ECHO/
		GOTO CLEANUPANDEXIT
	) ELSE (
	SET L1=!R1!
	GOTO EXTRACT
	)
)
ENDLOCAL
>nul 2>&1 DEL /F "%~dp0RescueMaker\Root\Windows\System32\WallpaperHost.exe"
REM Configure Rescue Disk
ECHO/
ECHO Adding Tools...
ECHO/
CALL :GETHDDTEST
CALL :GETCHKDSKGUI
CALL :GETDISMPLUS
CALL :GETUNLOCKER
CALL :GETEXPLORER
CALL :GETLAUNCHER
CALL :GETWALLPAPER
CALL :SETSTARTUP

:BURNMENU
SET "USBDISK="
SET "EXISTS="
SET "DTYPE2="
SET "L1="
SET "L2="
SET "LASTCHECK="
IF /I EXIST "%~dp0RescueMaker\*.diskpart" (
	DEL "%~dp0RescueMaker\*.diskpart" /F /Q>nul
)
CLS
ECHO Loading DISKs...               ^(Target must be USB^)
ECHO ===================================================
CALL :LISTDISKS
ECHO Press ENTER to refresh
ECHO/
SET /P USBDISK="Enter the USB DISK # you would like to use (X to Exit): "
IF "%USBDISK%"=="" (
	GOTO BURNMENU
)
IF /I "%USBDISK%"=="X" (
	ECHO/
	ECHO Aborting media creation and cleaning up cache folders...
	ECHO/
	GOTO CLEANUPANDEXIT
)
CALL :DISKEXIST %USBDISK% EXISTS
IF %EXISTS%==1 (
	ECHO/
	ECHO Disk %USBDISK% doesn't exist!
	ECHO/
	PAUSE
	GOTO BURNMENU
)
CALL :CHECKDISK %USBDISK%
SETLOCAL ENABLEDELAYEDEXPANSION
CALL :GETDISKTYPE DTYPE2
IF NOT "!DTYPE2!"=="USB" (
	DEL "%~dp0RescueMaker\currentdisk.diskpart" /F /Q>nul
	SET "USBDISK="
	ECHO/
	ECHO The selected disk is not a USB device. Only USB drives are supported at this time.
	ECHO/
	PAUSE
	ECHO/
	GOTO BURNMENU
)
CALL :VERIFYDELETE %USBDISK% LASTCHECK
IF "!LASTCHECK!"=="N" (
	GOTO BURNMENU
)
CALL :AVAILABLEDRIVELETTERS 2
>nul 2>&1 POWERSHELL -nop -c "clear-disk -number %USBDISK% -RemoveData -RemoveOEM -Confirm:$false"
>nul 2>&1 POWERSHELL -nop -c "Initialize-Disk -Number %USBDISK% -PartitionStyle MBR"
>nul 2>&1 POWERSHELL -nop -c "new-partition -disknumber %USBDISK% -size 2gb -driveletter !L2!"
>nul 2>&1 POWERSHELL -nop -c "new-partition -disknumber %USBDISK% -size $MaxSize -driveletter !L1!"
>nul 2>&1 POWERSHELL -nop -c "Format-Volume -DriveLetter !L2! -FileSystem FAT32 -Force -NewFileSystemLabel BOOTFILES"
>nul 2>&1 POWERSHELL -nop -c "Format-Volume -DriveLetter !L1! -FileSystem NTFS -Force -NewFileSystemLabel RescueDisk"
ECHO Copying files to USB, Please Wait... ^(This may take a few minutes^)
ECHO/
XCOPY "%~dp0RescueMaker\Root\" "!L1!:\" /E /H /C /I /Y /Z /G /Q
ECHO/
BCDBOOT !L1!:\Windows /s !L2!: /f ALL /d /addlast
MOUNTVOL !L2!: /D>nul
SETLOCAL DISABLEDELAYEDEXPANSION
ECHO/
ECHO Bootable USB Creation Complete!
ECHO/

:CLEANUPANDEXIT
REM Remove cache folders
POPD
>nul 2>&1 RD "%~dp0RescueMaker" /S /Q
PAUSE
REM Self delete and exit
(GOTO) 2>nul & del "%~f0">nul & EXIT

:LISTDISKS
(
	ECHO lis dis
)>"%~dp0RescueMaker\list.diskpart"
ECHO/
FOR /F "usebackq skip=2 tokens=1,2,4,5" %%a in (`DISKPART /S "%~dp0RescueMaker\list.diskpart" ^| FIND "Disk"`) DO (
	CALL :CHECKDISK %%b
	CALL :GETDISKNAME DNAME
	CALL :GETDISKTYPE DTYPE
	SETLOCAL ENABLEDELAYEDEXPANSION
	ECHO    Disk #^[%%b^]-^[%%c %%d^]-^[!DTYPE:USB=USB~!^]-^[!DNAME!^]
	ENDLOCAL
	DEL "%~dp0RescueMaker\currentdisk.diskpart" /F /Q>nul
)
DEL "%~dp0RescueMaker\list.diskpart" /F /Q
ECHO/
EXIT /b

:GETDISKNAME
FOR /F "usebackq skip=7 delims=" %%# in (`DISKPART /S "%~dp0RescueMaker\currentdisk.diskpart"`) DO (
	SET "%1=%%#"
	EXIT /B
)
EXIT /b

:GETDISKTYPE
FOR /F "usebackq tokens=3" %%# in (`DISKPART /S "%~dp0RescueMaker\currentdisk.diskpart" ^| FIND "Type"`) DO (
	SET "%1=%%#"
	EXIT /b
)
EXIT /b

:CHECKDISK
(
	ECHO SEL DIS %1
	ECHO DETAIL DISK
)>"%~dp0RescueMaker\currentdisk.diskpart"
EXIT/b

:VERIFYDELETE
(
	ECHO lis dis
)>"%~dp0RescueMaker\list.diskpart"
ECHO/
FOR /F "usebackq skip=2 tokens=1,2,4,5" %%a in (`DISKPART /S "%~dp0RescueMaker\list.diskpart" ^| FIND "Disk"`) DO (
	IF %1==%%b (
		CALL :CHECKDISK %%b
		CALL :GETDISKNAME DNAME
		CALL :GETDISKTYPE DTYPE
		SETLOCAL ENABLEDELAYEDEXPANSION
		ECHO    Disk #^[%%b^]-^[%%c %%d^]-^[!DTYPE:USB=USB~!^]-^[!DNAME!^] will be completely erased.
		ECHO/
		ENDLOCAL
		CHOICE /C YN /N /M "    Are you sure? This process is irreversable. [Y/N]: "
		IF !errorlevel!==2 (
			SET "%2=N"
		)
		DEL "%~dp0RescueMaker\currentdisk.diskpart" /F /Q>nul
		DEL "%~dp0RescueMaker\list.diskpart" /F /Q
		ECHO/
		EXIT /b
	)
)
EXIT /b

:GETHDDTEST
PUSHD "%~dp0RescueMaker\Junkbin"
POWERSHELL -nop -c "Start-BitsTransfer -Dynamic -Priority Foreground -Source https://newcontinuum.dl.sourceforge.net/project/crystaldiskinfo/9.1.1/CrystalDiskInfo9_1_1.zip -Destination '%~dp0RescueMaker\CrystalDiskInfo9_1_1.zip'"
MD "%~dp0RescueMaker\Root\Program Files\CrystalDisk"
7za.exe x -y "%~dp0RescueMaker\CrystalDiskInfo9_1_1.zip" -o"%~dp0RescueMaker\Root\Program Files\CrystalDisk">nul
POPD
EXIT /b

:GETCHKDSKGUI
PUSHD "%~dp0RescueMaker\Junkbin"
POWERSHELL -nop -c "Start-BitsTransfer -Priority Foreground -Source https://github.com/illsk1lls/RescueMaker/raw/main/.resources/cgui/cgui.7z -Destination '%~dp0RescueMaker\cgui.7z'"
MD "%~dp0RescueMaker\Root\Program Files\ChkDskGUI"
7za.exe x -y "%~dp0RescueMaker\cgui.7z" -o"%~dp0RescueMaker\Root\Program Files\ChkDskGUI">nul
POPD
EXIT /b

:GETDISMPLUS
PUSHD "%~dp0RescueMaker\Junkbin"
POWERSHELL -nop -c "Start-BitsTransfer -Priority Foreground -Source https://github.com/Chuyu-Team/Dism-Multi-language/releases/download/v10.1.1002.2/Dism++10.1.1002.1B.zip -Destination '%~dp0RescueMaker\Dism++10.1.1002.1B.zip'"
MD "%~dp0RescueMaker\Root\Program Files\DISM++"
7za.exe x -y "%~dp0RescueMaker\Dism++10.1.1002.1B.zip" -o"%~dp0RescueMaker\Root\Program Files\DISM++">nul
POPD
EXIT /b

:GETUNLOCKER
PUSHD "%~dp0RescueMaker\Junkbin"
POWERSHELL -nop -c "Start-BitsTransfer -Priority Foreground -Source https://github.com/illsk1lls/RescueMaker/raw/main/.resources/wlu/WLU.7z -Destination '%~dp0RescueMaker\WLU.7z'"
7za.exe x -y "%~dp0RescueMaker\WLU.7z" -o"%~dp0RescueMaker\Root\Windows\System32">nul
COPY /Y "%SystemDrive%\Windows\System32\offreg.dll" "%~dp0RescueMaker\Root\Windows\System32">nul
POPD
EXIT /b

:GETEXPLORER
PUSHD "%~dp0RescueMaker\Junkbin"
POWERSHELL -nop -c "Start-BitsTransfer -Priority Foreground -Source https://download.explorerplusplus.com/beta/1.4.0-beta-2/explorerpp_x64.zip -Destination '%~dp0RescueMaker\explorerpp_x64.zip'"
7za.exe x -y "%~dp0RescueMaker\explorerpp_x64.zip" -o"%~dp0RescueMaker\Root\Windows">nul
POPD
EXIT /b

:GETLAUNCHER
PUSHD "%~dp0RescueMaker\Junkbin"
POWERSHELL -nop -c "Start-BitsTransfer -Priority Foreground -Source https://github.com/complexlogic/flex-launcher/releases/download/v2.1/flex-launcher-2.1-win64.zip -Destination '%~dp0RescueMaker\flex-launcher-2.1-win64.zip'"; "Start-BitsTransfer -Priority Foreground -Source https://github.com/illsk1lls/RescueMaker/raw/main/.resources/flex/icons.7z -Destination '%~dp0RescueMaker\icons.7z'"
7za.exe x -y "%~dp0RescueMaker\flex-launcher-2.1-win64.zip" -o"%~dp0RescueMaker">nul
XCOPY "%~dp0RescueMaker\flex-launcher-2.1-win64\" "%~dp0RescueMaker\Root\Windows" /E /H /C /I /Y /Z /G /Q>nul
7za.exe x -y "%~dp0RescueMaker\icons.7z" -o"%~dp0RescueMaker\Root\Windows\assets\icons">nul
POPD
POWERSHELL -nop -c "Start-BitsTransfer -Priority Foreground -Source https://raw.githubusercontent.com/illsk1lls/RescueMaker/main/.resources/flex/config.ini -Destination '%~dp0RescueMaker\Root\Windows\config.ini'"
EXIT /b

:GETWALLPAPER
POWERSHELL -nop -c "Start-BitsTransfer -Priority Foreground -Source https://github.com/illsk1lls/RescueMaker/raw/main/.resources/wallpaper.jpg -Destination '%~dp0RescueMaker\winre.jpg'"
>nul 2>&1 MOVE /Y "%~dp0RescueMaker\winre.jpg" "%~dp0RescueMaker\Root\Windows\System32"
EXIT /b

:SETSTARTUP
(
	ECHO [LaunchApp]
	ECHO AppPath=%%SystemDrive%%\Windows\flex-launcher.exe
)>"%~dp0RescueMaker\Root\Windows\System32\winpeshl.ini"
EXIT /b

:AVAILABLEDRIVELETTERS
SET LT=%1
SET "L1="
SET "L2="
FOR %%# IN (D E F G H I J K L M N O P Q R S T U V W X Y Z) DO (
	SET CURRENT=%%#
	IF NOT EXIST !CURRENT!:\* (
		SET UNUSABLE=0
		FOR /F "usebackq tokens=3" %%# in (`FSUTIL FSINFO drivetype !CURRENT!:`) DO (
			IF /I "%%#"=="CD-ROM" (
				SET UNUSABLE=1
			)
			IF NOT "!UNUSABLE!"=="1" (
				FOR /F "usebackq tokens=3" %%# in (`FSUTIL FSINFO drivetype !CURRENT!:`) DO (
					IF /I "%%#"=="No" (
						SET L!LT!=!CURRENT!
						SET /A LT-=1
					)
				)
			)
		)
	)
	IF !LT! LEQ 0 (
		ENDLOCAL
		EXIT /b
	)
)
EXIT /b

:DISKEXIST
>nul 2>&1 POWERSHELL -nop -c "Get-Disk %1"
SET %2=%errorlevel%
EXIT /b

:FINDRE
SET "RT=1"
SET "R1="
FOR %%# IN (A B C D E F G H I J K L M N O P Q R S T U V W X Y Z) DO (
	IF EXIST %%#:\Recovery\WindowsRE\WinRE.wim (
		SET NOUNMOUNT=1
		SET R!RT!=%%#
		SET /A RT+=1
	)
	IF EXIST %%#:\Windows\System32\Recovery\WinRE.wim (
		SET "WinRePath=Windows\System32\Recovery"
		SET NOUNMOUNT=1
		SET R!RT!=%%#
		SET /A RT+=1
	)
	IF !RT! GEQ 2 (
		ENDLOCAL
		EXIT /b
	)
)
EXIT /b

:SETTERMINAL
SET "LEGACY={B23D10C0-E52E-411E-9D5B-C09FDF709C7D}"
SET "TERMINAL={2EACA947-7F5F-4CFA-BA87-8F7FBEEFBE69}"
SET "TERMINAL2={E12CFF52-A866-4C77-9A90-F570A7AA2C6B}"
POWERSHELL -nop -c "Get-WmiObject -Class Win32_OperatingSystem | Select -ExpandProperty Caption | Find 'Windows 11'">nul && (
	SET isEleven=1
	FOR /F "usebackq tokens=3" %%# IN (`REG QUERY "HKCU\Console\%%%%Startup" /v DelegationConsole 2^>nul`) DO (
		IF NOT "%%#"=="%LEGACY%" (
			SET "DEFAULTCONSOLE=%%#"
			REG ADD "HKCU\Console\%%%%Startup" /v DelegationConsole /t REG_SZ /d "%LEGACY%" /f>nul
			REG ADD "HKCU\Console\%%%%Startup" /v DelegationTerminal /t REG_SZ /d "%LEGACY%" /f>nul
		)
	)
)
FOR /F "usebackq tokens=3" %%# IN (`REG QUERY "HKCU\Console" /v ForceV2 2^>nul`) DO (
	IF NOT "%%#"=="0x1" (
		SET LEGACYTERM=0
		REG ADD "HKCU\Console" /v ForceV2 /t REG_DWORD /d 1 /f>nul
	) ELSE (
		SET LEGACYTERM=1
	)
)
EXIT /b

:RESTORETERMINAL
IF "%isEleven%"=="1" (
	IF DEFINED DEFAULTCONSOLE (
		IF "%DEFAULTCONSOLE%"=="%TERMINAL%" (
			REG ADD "HKCU\Console\%%%%Startup" /v DelegationConsole /t REG_SZ /d "%TERMINAL%" /f>nul
			REG ADD "HKCU\Console\%%%%Startup" /v DelegationTerminal /t REG_SZ /d "%TERMINAL2%" /f>nul
		) ELSE (
			REG ADD "HKCU\Console\%%%%Startup" /v DelegationConsole /t REG_SZ /d "%DEFAULTCONSOLE%" /f>nul
			REG ADD "HKCU\Console\%%%%Startup" /v DelegationTerminal /t REG_SZ /d "%DEFAULTCONSOLE%" /f>nul
		)
	)
)
IF "%LEGACYTERM%"=="0" (
	REG ADD "HKCU\Console" /v ForceV2 /t REG_DWORD /d 0 /f>nul
)
EXIT /b