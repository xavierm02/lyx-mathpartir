Function LaTeXActions
 # check if MiKTeX or TeXLive is installed

  # test if MiKTeX is installed
  # reads the PATH variable via the registry because NSIS' "$%Path%" variable is not updated when the PATH changes
  ReadRegStr $String HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "Path"
  StrCpy $Search "miktex"
  Call LaTeXCheck # sets the path to the latex.exe to $PathLaTeX # Function from LyXUtils.nsh
  
  ${if} $PathLaTeX != ""
   # check if MiKTeX 2.7 or newer is installed
   StrCpy $0 0
   loopA:
    EnumRegKey $1 HKLM "SOFTWARE\MiKTeX.org\MiKTeX" $0 # check the last subkey
    StrCmp $1 "" doneA
    StrCpy $String $1
    IntOp $0 $0 + 1
    Goto loopA
   doneA:
   ${if} $String == "2.7"
    StrCpy $MiKTeXVersion "2.7"
    StrCpy $LaTeXName "MiKTeX 2.7"
   ${endif}
   ${if} $String == "2.8"
    StrCpy $MiKTeXVersion "2.8"
    StrCpy $LaTeXName "MiKTeX 2.8"
   ${endif}
   ${if} $String == "2.9"
    StrCpy $MiKTeXVersion "2.9"
    StrCpy $LaTeXName "MiKTeX 2.9"
   ${endif}
  ${endif}
  
  ${if} $PathLaTeX == "" # check if MiKTeX is installed only for the current user
   ReadRegStr $String HKCU "Environment" "Path"
   StrCpy $Search "miktex"
   Call LaTeXCheck # function from LyXUtils.nsh
   ${if} $PathLaTeX != ""
    StrCpy $MiKTeXUser "HKCU" # needed later to configure MiKTeX
   ${endif}
  ${endif}
  ${if} $LaTeXName == "" # check for the MiKTeX version
   StrCpy $0 0
   loopB:
    EnumRegKey $1 HKCU "SOFTWARE\MiKTeX.org\MiKTeX" $0 # check the last subkey
    StrCmp $1 "" doneB
    StrCpy $String $1
    IntOp $0 $0 + 1
    Goto loopB
   doneB:
   ${if} $String == "2.7"
    StrCpy $MiKTeXVersion "2.7"
    StrCpy $LaTeXName "MiKTeX 2.7"
   ${endif}
   ${if} $String == "2.8"
    StrCpy $MiKTeXVersion "2.8"
    StrCpy $LaTeXName "MiKTeX 2.8"
   ${endif}
   ${if} $String == "2.9"
    StrCpy $MiKTeXVersion "2.9"
    StrCpy $LaTeXName "MiKTeX 2.9"
   ${endif}
  ${endif}
    
  ${if} $PathLaTeX != ""
   StrCpy $LaTeXInstalled "MiKTeX"
  ${endif}
  
  # test if TeXLive is installed
  # as described at TeXLives' homepage there should be an entry in the PATH
  ${if} $PathLaTeX == ""
   ReadRegStr $String HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "Path"
   StrCpy $Search "TeXLive"
   Call LaTeXCheck # function from LyXUtils.nsh
  ${endif}
  # check for the current user Path variable (the case when it is a live CD/DVD)
  ${if} $PathLaTeX == ""
   ReadRegStr $String HKCU "Environment" "Path"
   StrCpy $Search "texlive"
   StrCpy $2 "TeXLive"
   Call LaTeXCheck # function from LyXUtils.nsh
  ${endif}
  # check if the variable TLroot exists (the case when it is installed using the program "tlpmgui")
  ${if} $PathLaTeX == ""
   ReadRegStr $String HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "TLroot"
   ${if} $String == ""
    ReadRegStr $String HKCU "Environment" "TLroot" # the case when installed without admin permissions
   ${endif}
   StrCpy $PathLaTeX "$String\bin\win32"
   # check if the latex.exe exists in the $PathLaTeX folder
   !insertmacro FileCheck $5 "latex.exe" "$PathLaTeX" # macro from LyXUtils.nsh
   ${if} $5 == "False"
    StrCpy $PathLaTeX ""
   ${endif}
  ${endif}
  ${if} $PathLaTeX != ""
  ${andif} $LaTeXName != "MiKTeX 2.7"
  ${andif} $LaTeXName != "MiKTeX 2.8"
  ${andif} $LaTeXName != "MiKTeX 2.9"
   StrCpy $LaTeXName "TeXLive"
  ${endif}
  
  ${if} $PathLaTeX == ""
   StrCpy $MissedProg "True"
  ${endif}

FunctionEnd

# -------------------------------------------

!if ${SETUPTYPE} == BUNDLE

 Function InstallMiKTeX
  
  # install MiKTeX if not already installed
  ${if} $PathLaTeX == ""
   # launch MiKTeX's installer
   MessageBox MB_OK|MB_ICONINFORMATION "$(LatexInfo)"
   ExecWait ${MiKTeXInstall}
   # test if MiKTeX is installed
   ReadRegStr $String HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "Path"
   StrCpy $Search "miktex"
   Call LaTeXCheck # function from LyXUtils.nsh
   ${if} $PathLaTeX == ""
    StrCpy $MiKTeXUser "HKCU"
    ReadRegStr $String HKCU "Environment" "Path"
    StrCpy $Search "miktex"
    Call LaTeXCheck # function from LyXUtils.nsh
   ${endif}
   ${if} $PathLaTeX != ""
    # set package repository (MiKTeX's primary package repository)
    WriteRegStr HKLM "SOFTWARE\MiKTeX.org\MiKTeX" "OnlyWithLyX" "Yes${APP_SERIES_KEY}" # special entry to tell the uninstaller that it was installed with LyX
    StrCpy $LaTeXInstalled "MiKTeX"
    StrCpy $MiKTeXVersion ${MiKTeXDeliveredVersion}
   ${else}
    MessageBox MB_OK|MB_ICONSTOP "$(LatexError1)"
    SetOutPath $TEMP # to be able to delete the $INSTDIR
    RMDir /r $INSTDIR
    Abort
   ${endif} # endif $PathLaTeX != ""
  ${endif}

  FunctionEnd

!endif # endif ${SETUPTYPE} == BUNDLE

# ------------------------------

Function ConfigureMiKTeX
 # installs the LaTeX class files that are delivered with LyX
 # and enable MiKTeX's automatic package installation
 
  ${if} $MultiUser.Privileges != "Admin"
  ${orif} $MultiUser.Privileges != "Power"
   StrCpy $PathLaTeXLocal "$PathLaTeX" -11 # delete "\miktex\bin"
  ${else}
   StrCpy $PathLaTeXLocal "$APPDATA\MiKTeX\$MiKTeXVersion"
  ${endif}

  # only install the LyX packages if they are not already installed
  ${ifnot} ${FileExists} "$PathLaTeXLocal\tex\latex\lyx\broadway.cls"
   # dvipost
   SetOutPath "$PathLaTeXLocal\tex\latex\dvipost"
   File "${FILES_DVIPOST_PKG}\dvipost.sty"
   # LyX files in Resources\tex
   SetOutPath "$PathLaTeXLocal\tex\latex\lyx"
   CopyFiles /SILENT "$INSTDIR\Resources\tex\*.*" "$PathLaTeXLocal\tex\latex\lyx"
  
   # refresh MiKTeX's file name database
   ${if} $MiKTeXUser != "HKCU" # call the admin version when the user is admin
    nsExec::ExecToLog '"$PathLaTeX\initexmf --admin --update-fndb"'
   ${else} 
    nsExec::ExecToLog '"$PathLaTeX\initexmf --update-fndb"'
   ${endif}
   Pop $UpdateFNDBReturn # Return value
  ${endif}
  
  # enable package installation without asking (1 = Yes, 0 = No, 2 = Ask me first)
  WriteRegStr HKCU "SOFTWARE\MiKTeX.org\MiKTeX\$MiKTeXVersion\MPM" "AutoInstall" "1" # if only for current user
  ${if} $MiKTeXUser != "HKCU"
   WriteRegStr SHCTX "SOFTWARE\MiKTeX.org\MiKTeX\$MiKTeXVersion\MPM" "AutoInstall" "1"
  ${endif}
  # set package repository (MiKTeX's primary package repository)
  WriteRegStr HKCU "SOFTWARE\MiKTeX.org\MiKTeX\$MiKTeXVersion\MPM" "RemoteRepository" "${MiKTeXRepo}" # if only for current user
  WriteRegStr HKCU "SOFTWARE\MiKTeX.org\MiKTeX\$MiKTeXVersion\MPM" "RepositoryType" "remote" # if only for current user
  ${if} $MiKTeXUser != "HKCU"
   WriteRegStr SHCTX "SOFTWARE\MiKTeX.org\MiKTeX\$MiKTeXVersion\MPM" "RemoteRepository" "${MiKTeXRepo}"
   WriteRegStr SHCTX "SOFTWARE\MiKTeX.org\MiKTeX\$MiKTeXVersion\MPM" "RepositoryType" "remote"
  ${endif}
  
  # enable MiKTeX's automatic package installation
  ExecWait '$PathLaTeX\mpm.exe --update-fndb'
  # the following feature is planned to be used for a possible CD-version
  # copy LaTeX-packages needed by LyX
  # SetOutPath "$INSTDIR"
  # File /r "${LaTeXPackagesDir}" 
  
FunctionEnd

Function UpdateMiKTeX
 # ask to update MiKTeX

  ${if} $LaTeXInstalled == "MiKTeX"
   MessageBox MB_YESNO|MB_ICONINFORMATION "$(MiKTeXInfo)" IDYES UpdateNow IDNO UpdateLater
   UpdateNow:
    StrCpy $0 $PathLaTeX -4 # remove "\bin"
    # the update wizard is either started by the copystart_admin.exe
    # or the miktex-update.exe (since MiKTeX 2.8)
    ExecWait '"$PathLaTeX\copystart_admin.exe" "$0\config\update.dat"' # run MiKTeX's update wizard
    ${if} $MiKTeXUser != "HKCU" # call the admin version when the user is admin
     ExecWait '"$PathLaTeX\internal\miktex-update_admin.exe"' # run MiKTeX's update wizard
    ${else} 
     ExecWait '"$PathLaTeX\internal\miktex-update.exe"' # run MiKTeX's update wizard
    ${endif} 
   UpdateLater:
  ${endif}

FunctionEnd
