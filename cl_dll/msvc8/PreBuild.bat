::
:: Pre-build auto-versioning script
::
::

SET srcdir=%~1
SET repodir=%~2

set old_version=
set version_revision=
set version_date=
set version_pdate=
set version_pdate_1=
set version_pdate_2=
set version_major=
set version_minor=
set version_maintenance=
set version_modifications=

::
:: Check for SubWCRev.exe presence
::
SubWCRev.exe 2>NUL >NUL

::
:: Read old appversion.h, if present
::
IF EXIST "%srcdir%\appversion.h" (
	FOR /F "usebackq tokens=1,2,3" %%i in ("%srcdir%\appversion.h") do (
		IF %%i==#define (
			IF %%j==APP_VERSION_C SET old_version=%%k
		)
	)
)

IF NOT "%ERRORLEVEL%" == "1" (
	echo can't locate SubWCRev.exe - auto-versioning step won't be performed

	:: if we haven't appversion.h, we need to create it
	IF "%old_version%" == "" (
		set version_revision=0
		set version_date=?
		goto _readVersionH
	)
	exit /B 0
)

::
:: Create template file for SubWCRev
::

:: Use creation time as prefix
SET TempFile=%Time%

:: Remove time delimiters
SET TempFile=%TempFile::=%
SET TempFile=%TempFile:.=%
SET TempFile=%TempFile:,=%
SET TempFile=%TempFile: =%

:: Create a really large random number and append it to the prefix
SET TempFile=%TempFile%%Random%
SET TempFile=%TempFile%%Random%

echo #define SVNV_REVISION ^$WCREV^$ >"%Temp%.\%TempFile%.templ"
echo #define SVNV_DATE ^$WCDATE=^%%Y-^%%m-^%%d__^%%H-^%%M-^%%S^$ >>"%Temp%.\%TempFile%.templ"
echo #define SVNV_PDATE_1 ^$WCDATE=^%%Y-^%%m-^%%d^$ >>"%Temp%.\%TempFile%.templ"
echo #define SVNV_PDATE_2 ^$WCDATE=^%%H:^%%M:^%%S^$ >>"%Temp%.\%TempFile%.templ"
echo .  >>"%Temp%.\%TempFile%.templ"

::
:: Process template
::
SubWCRev.exe "%repodir%\." "%Temp%.\%TempFile%.templ" "%Temp%.\%TempFile%.h" >NUL

IF NOT "%ERRORLEVEL%" == "0" (
	echo SubWCRev.exe done with errors [%ERRORLEVEL%].
	echo Check if you have correct SVN repository at '%repodir%'
	echo Auto-versioning step will not be performed.

	DEL /F /Q "%Temp%.\%TempFile%.templ" 2>NUL
	DEL /F /Q "%Temp%.\%TempFile%.h" 2>NUL

	:: if we haven't appversion.h, we need to create it
	IF "%old_version%" == "" (
		set version_revision=0
		set version_date=?
		goto _readVersionH
	)
	exit /B 0
)

DEL /F /Q "%Temp%.\%TempFile%.templ" 2>NUL

::
:: Read revision and release date from it
::
FOR /F "usebackq tokens=1,2,3" %%i in ("%Temp%.\%TempFile%.h") do (
	IF %%i==#define (
		IF %%j==SVNV_REVISION SET version_revision=%%k
		IF %%j==SVNV_DATE SET version_date=%%k
		IF %%j==SVNV_PDATE_1 SET version_pdate_1=%%k
		IF %%j==SVNV_PDATE_2 SET version_pdate_2=%%k
	)
)

DEL /F /Q "%Temp%.\%TempFile%.h" 2>NUL
SET version_pdate=%version_pdate_1% %version_pdate_2%

::
:: Detect changes and mixed revisions
::
SubWCRev.exe "%repodir%\." >NUL

IF "%ERRORLEVEL%" == "7" (
	echo SubWCRev.exe detected modifications.
	set version_modifications="7"
) ELSE IF "%ERRORLEVEL%" == "8" (
	echo SubWCRev.exe detected mixed revisions.
	set version_modifications="8"
)

:_readVersionH
::
:: Read major, minor and maintenance version components from Version.h
::
FOR /F "usebackq tokens=1,2,3" %%i in ("%srcdir%\version.h") do (
	IF %%i==#define (
		IF %%j==VERSION_MAJOR SET version_major=%%k
		IF %%j==VERSION_MINOR SET version_minor=%%k
		IF %%j==VERSION_MAINTENANCE SET version_maintenance=%%k
	)
)

::
:: Now form full version string like "1.0.0.1"
::
IF "%version_maintenance%" == "" (
	set new_version=%version_major%,%version_minor%,0,%version_revision%
) ELSE (
	set new_version=%version_major%,%version_minor%,%version_maintenance%,%version_revision%
)

::
:: Update appversion.h if version has changed
::
IF NOT "%new_version%"=="%old_version%" (

	echo Updating appversion.h, new version is %new_version%, the old one was %old_version%
	echo #ifndef __APPVERSION_H__ >"%srcdir%\appversion.h"
	echo #define __APPVERSION_H__ >>"%srcdir%\appversion.h"
	echo.  >>"%srcdir%\appversion.h"
	echo // >>"%srcdir%\appversion.h"
	echo // This file is generated automatically. >>"%srcdir%\appversion.h"
	echo // Don't edit it. >>"%srcdir%\appversion.h"
	echo // >>"%srcdir%\appversion.h"
	echo.  >>"%srcdir%\appversion.h"
	echo //Version defines >>"%srcdir%\appversion.h"

	IF "%version_maintenance%" == "" (
		echo #define APP_VERSION_D %version_major%.%version_minor%.%version_revision% >>"%srcdir%\appversion.h"
		echo #define APP_VERSION_STRD "%version_major%.%version_minor%.%version_revision%" >>"%srcdir%\appversion.h"
		echo #define APP_VERSION_C %version_major%,%version_minor%,0,%version_revision% >>"%srcdir%\appversion.h"
		echo #define APP_VERSION_STRCS "%version_major%, %version_minor%, 0, %version_revision%" >>"%srcdir%\appversion.h"
	) ELSE (
		echo #define APP_VERSION_D %version_major%.%version_minor%.%version_maintenance%.%version_revision% >>"%srcdir%\appversion.h"
		echo #define APP_VERSION_STRD "%version_major%.%version_minor%.%version_maintenance%.%version_revision%" >>"%srcdir%\appversion.h"
		echo #define APP_VERSION_C %version_major%,%version_minor%,%version_maintenance%,%version_revision% >>"%srcdir%\appversion.h"
		echo #define APP_VERSION_STRCS "%version_major%, %version_minor%, %version_maintenance%, %version_revision%" >>"%srcdir%\appversion.h"
	)


	echo.  >>"%srcdir%\appversion.h"
	echo #define APP_VERSION_DATE %version_date% >>"%srcdir%\appversion.h"
	echo #define APP_VERSION_DATE_STR "%version_date%" >>"%srcdir%\appversion.h"
	echo.  >>"%srcdir%\appversion.h"
	echo #define APP_VERSION_PDATE_STR "%version_pdate%" >>"%srcdir%\appversion.h"
	echo.  >>"%srcdir%\appversion.h"
	echo #define APP_VERSION_YMD_STR "%version_pdate_1%" >>"%srcdir%\appversion.h"
	echo.  >>"%srcdir%\appversion.h"

	echo #endif //__APPVERSION_H__ >>"%srcdir%\appversion.h"
	echo.  >>"%srcdir%\appversion.h"

	IF "%version_modifications%" == "7" (
		echo #define APP_VERSION_FLAGS VS_FF_SPECIALBUILD >>"%srcdir%\appversion.h"
		echo #define APP_VERSION_SPECIALBUILD "modified" >>"%srcdir%\appversion.h"
	) ELSE IF "%version_modifications%" == "8" (
		echo #define APP_VERSION_FLAGS VS_FF_SPECIALBUILD >>"%srcdir%\appversion.h"
		echo #define APP_VERSION_SPECIALBUILD "mixed" >>"%srcdir%\appversion.h"
	) ELSE (
		echo #define APP_VERSION_FLAGS 0x0L >>"%srcdir%\appversion.h"
		echo #define APP_VERSION_SPECIALBUILD "" >>"%srcdir%\appversion.h"
	)

)

:_exit
exit /B 0