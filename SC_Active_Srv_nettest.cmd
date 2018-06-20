:: Starconflict game servers tester 
::
:: PURPOSE: - do network tests via active or latest DS server found in latest game.log
::          - show active/latest game servers
::
::
:: VER.       HISTORY
:: 0.1.0      03.12.2014    * Initial release
:: 0.1.1      05.12.2014    - Date added, fixed DS existance logic
:: 0.2.0      10.12.2014    - Monitor + separate ping window +last map stats
:: 0.3.0      14.12.2014    - Redesign monitor for loop cycles
:: 0.3.1      15.12.2014    - Fixed massping to support ENG windows
:: 0.3.2      16.12.2014    - Fixed cping output on host unreach
:: 0.3.3      17.12.2014    - Added region info
:: 0.4.0      26.02.2015	- Switched to pathping
:: 0.4.1      08.04.2015	- Added mtu size test with ping -l...
:: 0.4.2      29.05.2015	- Do tracert before pathping to resolve hops. 
::                              pathping may not do this thuough the whole path 
::                              if there were two unreachable hops on the way
:: 0.4.2.1    17.11.2015    +95.213 RU nodes
:: 0.4.2.2    19.11.2015    +185.106 RU nodes
:: 0.4.2.3    15.03.2017    +81.171 EU
:: 0.4.3.0    11.05.2017    - support for WinMtr
@Set PINGNUM=50
@Set LOGDIR="%userprofile%\Documents\My Games\StarConflict\logs"

:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::  main
:: 
@Echo Off
Setlocal  EnableDelayedExpansion
Set PATH=%WINDIR%\System32;%WINDIR%
Set DEBUG=0
Set MTUTESTSIZE_HI=1472
Set MTUTESTSIZE_LO=1432
::Set MTUTESTSIZE_HI=1572
::Set MTUTESTSIZE_LO=1500

Set REGIONDB=188.93_185.106_95.213_91.230_5.178_46.46:RU 81.171_5.153_159.8:EU 119.81:AS 198.11:US

If %1.==getlogstr. Call :GrepLogFile %2 & Exit
If %1.==ping. Call :DoPing %2 %3 & Exit /B
If %1.==trace. Call :DoTrace %2 %3 & Exit /B
If %1.==test. Call :DoTests %2 %3 %4 %5 %6 %7 %8 %9 & Exit /B
If %1.==mon0. Call :mon0 %2 %3 %4 %5 & Exit
If %1.==mon1. Call :mon1 %2 %3 %4 %5 & Exit
if %1.==getregion. Call :_PrintRegion %2 %REGIONDB% & Exit


Echo Waiting for DS server record in game.log
Call :_Echo "play any map to continue or press CtrlC to exit..."
:_wait_for_ds
For /F "usebackq tokens=1 delims=(|:" %%a in (`%~dnx0 getlogstr ds`)Do (  
        Set DS=%%a        
        Echo !DS! | FindStr /R /C:"[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*" >nul || ( 
                Call :_Echo "."
                Timeout /T 3 >nul
                GoTo :_wait_for_ds
                 )
)
Echo DS record found


For /F "usebackq tokens=1 delims=(|:" %%a in (`%~dnx0 getlogstr shard`)Do Set SHARD=%%a
For /F "usebackq tokens=1 delims=(|:" %%a in (`%~dnx0 getlogstr lb`)Do Set LB=%%a
For /F "usebackq tokens=1 delims=(|:" %%a in (`%~dnx0 getlogstr chat`)Do Set CHAT=%%a
For /F "usebackq tokens=*" %%a in (`%~dnx0 getlogstr tz`)Do Set TZN=%%a

Set DS_REG=--&Set SHARD_REG=--&Set CHAT_REG=--&Set LB_REG=--
For /F "usebackq tokens=1,2 delims=: " %%a In (`%~dnx0 getregion %DS%`) Do Set DS_REG=%%b
For /F "usebackq tokens=1,2 delims=: " %%a In (`%~dnx0 getregion %SHARD%`) Do Set SHARD_REG=%%b
For /F "usebackq tokens=1,2 delims=: " %%a In (`%~dnx0 getregion %LB%`) Do Set LB_REG=%%b
For /F "usebackq tokens=1,2 delims=: " %%a In (`%~dnx0 getregion %CHAT%`) Do Set CHAT_REG=%%b


For /F "usebackq tokens=*" %%a in (`%~dnx0 getlogstr avgping`)Do (
        Set LASTPING=%%a
        Echo !LASTPING! | FindStr /C:"avgPacketLoss" >nul || ( 
        Set LASTPING=
        )
)

If /I %1.==monitor. GoTo :DoMonitor
If /I %1.==mon. GoTo :DoMonitor

Call :Stats
If %1.==stats. Exit /B

start "Testing DS" /MAX  %~dnx0 test %LB% %LB_REG% %SHARD% %SHARD_REG% %CHAT% %CHAT_REG% %DS% %DS_REG%


Exit 0





::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: functions go futher
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

::
:: mon0 - 1st monitor window
::
:mon0
Set LOG=nettest-tracing.%DATE%.log
Cls
 Echo.
 For /F "usebackq tokens=*" %%a in (`%~dnx0 getlogstr tz`)Do Set TZN=%%a
 Echo // >> %LOG% & Echo //Starting >> %LOG% & Echo // >> %LOG%
 Echo !TZN! >> %LOG%

 Echo %TIME:~0,-3% !TZN!
 Echo Tracing current server. 
 Echo Log file is: %LOG%
 Echo.
:mon0_loop 
 For /F "usebackq tokens=1 delims=(|:" %%a in (`%~dnx0 getlogstr ds`)Do (
        Set DS=%%a
        Echo !DS! | FindStr /R /C:"[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*" >nul || ( 
                Echo DS server not found. Restart this script to fix the issue. 
                Exit
               )
 )
 Set /A CNT+=1
 Echo [%TIME:~0,-3%] Run %CNT%. Collecting tracing data. Press Ctrl-C to abort...
 Echo [%TIME:~0,-3%] Trace run: %CNT% >> %LOG%
 tracert  -d -w 2000 -4 %DS% > "%TEMP%\%LOG%.~" & type "%TEMP%\%LOG%.~" & type "%TEMP%\%LOG%.~" >> %LOG%
 GoTo :mon0_loop 
Exit

::
:: mon1 - 2nd monitor window
::
:mon1
Cls
 Echo.
 For /F "usebackq tokens=*" %%a in (`%~dnx0 getlogstr tz`)Do Set TZN=%%a

 Echo %TIME:~0,-3% !TZN!
 Echo Pinging current server. Press Ctrl-C to stop ping loop
 Echo.
:mon1_loop 
 For /F "usebackq tokens=1 delims=(|:" %%a in (`%~dnx0 getlogstr ds`)Do (
        Set DS=%%a
        Echo !DS! | FindStr /R /C:"[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*" >nul || ( 
                Echo DS server not found. Restart this script to fix the issue. 
                Exit
               )
 )
 Call :_cping %DS% 
 GoTo :mon1_loop 
Exit

::
:: Monitors game.log for loss strings then run test functions against active ds
::
:DoMonitor
 Set WAIT=1
 Set PAT=loss.*[1-9][0-9]\.[0-9]*%%
 Echo.

 Echo Monitoring game.log for packet loss record ^>10%% at %WAIT% seconds intervals
 Call :_Echo press CtrlC to interrupt 
 For /F "usebackq tokens=*" %%a In (`ForFiles /P %LOGDIR% /M game.log /S /D 0 /C "cmd /c findstr /R \"%PAT%\" @path"`) Do Set PL0=%%a


:DoMonLoop 
  For /F "usebackq tokens=*" %%a In (`ForFiles /P %LOGDIR% /M game.log /S /D 0 /C "cmd /c findstr /R \"%PAT%\" @path"`) Do Set PL1=%%a
  If Not "!PL0!"=="!PL1!" (
    Echo . gotcha^!
    Call :_chkWinMtrExistance
    If /I "!WINMTR!"=="True" (
        For /F "usebackq tokens=1 delims=(|:" %%a in (`%~dnx0 getlogstr ds`)Do Set DS=%%a
        start WinMtr.exe !DS!
    ) Else (
        Start /MAX %~dnx0 mon0
        Timeout /T 1 >nul
        Start %~dnx0 mon1 
    )
    Exit /B
  ) 

 Call :_Echo "."
 Timeout /T %WAIT% >nul
 GoTo :DoMonLoop 
 Echo done
Exit /B




::
:: Just print statistics
::
:Stats

Echo.
Echo servers found in latest game.log
Echo LoadBalancer       [%LB_REG%] %LB%
Echo Shard              [%SHARD_REG%] %SHARD%
Echo Chat               [%CHAT_REG%] %CHAT%
Echo Dedicated          [%DS_REG%] %DS%
Echo.
If Defined LASTPING Echo last stats: !LASTPING!

GoTo :eof


::
:: Run ping and traceroute against active/last DS
::
:: %1: LB
:: %2: LB_Region
:: %3: SHARD
:: %4: SHARD_Region
:: %5: CHAT
:: %6: CHAT_Region
:: %7: DS
:: %8: DS_Region
:DoTests
Echo.
Echo *********************************************************
Echo *    Last servers used                                  *
Echo * [parsed from latest game.log]                         *
Echo *********************************************************
Echo %TIME:~0,-3% !TZN!
Echo. 
Echo LoadBalancer       [%2] %1
Echo Shard              [%4] %3
Echo Chat               [%6] %5
Echo Dedicated          [%8] %7
If %7%8.==. ( Echo ERROR: to few args given. Specify full ip list.  & pause & Exit 1)

Echo.&Echo ---------------------------------------------------------
Call :_Echo [INFO] check MSS with %MTUTESTSIZE_HI% byte nofrag packets...
Ping -n 2 -f -l %MTUTESTSIZE_HI% %7 >nul && Echo OK || (
  Echo FAILED
  Echo [WARN] your MSS is squeezed. 
  Call :_Echo  [INFO] check MSS with %MTUTESTSIZE_LO% byte nofrags...
  Ping -n 2 -f -l %MTUTESTSIZE_LO% %7 >nul && ( 
	Echo OK&Echo.
         Echo [FIX] ----[FIX]-----[FIX]-----[FIX]-----[FIX]-----[FIX]-----[FIX]-----[FIX]
         Echo       use the following command to fix your networking issues
         Echo.  
         Echo       Netsh int ipv4 set sub "INTERFACE_NAME" mtu=1460 store=persistent
	 Echo.
         Echo                        ,where INTERFACE_NAME is one of the shown below.
         Echo                                  usually its Local Area Connection - for cable
         Echo                                  Wireless Network Connection       - for Wi-Fi
         Echo       for example ^(note the quotes^)^:
	 Echo       Netsh int ipv4 set sub "Local Area Connection" mtu=1460 store=persistent
	 Echo.
	) || Echo [FAILED]
 	 Echo.
	 Echo  Use correct interface name from the rightmost column to fix MTU with netsh^:
        netsh interface ipv4 show subinterface
)

Echo.&Echo ---------------------------------------------------------

Call :_chkWinMtrExistance

If /I "!WINMTR!"=="True" (
  start WinMtr.exe %7
) Else (
  Echo [INFO] Display back-resolved hops...
  TraceRt -w 3000 %7
  Echo.

  Echo [INFO] Checking Nodes and Links packet losses...
  PathPing -n -4 -w 500 %7
  rem start "Pinging latest dedicated server"  %~dnx0 ping %7 "Do a ping test with %PINGNUM% icmp requests"
  Echo.
)
If Defined LASTPING Echo last map: avgPing !LASTPING!
rem Call :DoTrace %7 "Tracing route "
Echo %TIME:~0,-3% !TZN!
Goto :Eof


::
:: check WinMtr exists and set WINMTR to False or True
:: 
:_chkWinMtrExistance
  Set WINMTR=False  
  
  For /F "usebackq" %%a In (`Where winmtr.exe  2^>nul`) Do Set WINMTR=True

  If /I "%WINMTR%"=="True" (
      Echo Found WinMTR. Will use it for tests
  ) Else (
      Echo [WARNING] WinMtr NOT Found. Will use windows utilities instead
      Echo.
      Echo **************************************************
      Echo * You are suggested to put winmtr.exe nearby
      Echo *  please get it from http://winmtr.net
      Echo **************************************************
      Echo.
  )
Goto :Eof

::
:: traceroute to given host
::
:DoTrace
  tracert  -d -w 2000 -4 %1
Goto :Eof


::
:: ping given host
::
:DoPing
  Echo *********************************************************
  Echo *  %~2
  Echo *********************************************************

  ping -n %PINGNUM% -w 2000 -l 64 -f -4 %1
Goto :Eof



::
:: print latest string found by confgired pattern out of the latest game.log 
::
:GrepLogFile
  If %1.==ds. (
          Set PAT=client: connected to 
  )  Else If %1.==shard. (
                  Set PAT=connected to shard 
  )  Else If %1.==lb. (
                  Set PAT=connected to load balancer 
  )  Else If %1.==chat. (
                  Set PAT=chat server address 
  )  Else If %1.==avgping. (
                  Set PAT=avgPing 
  )  Else If %1.==tz. (
                  Set PAT=--- Date: 
  ) Else (
    Exit 1 
  )

  For /F "usebackq tokens=*" %%a In (`ForFiles /P %LOGDIR% /M game.log /S /D 0 /C "cmd /c findstr /R /C:\"%PAT%\" @path" 2^>nul`) Do Set STR=%%a
  If "%DEBUG%"=="1" Echo !STR:*%PAT%=! >> debug.log
  Echo !STR:*%PAT%=!
Goto :Eof

::
:: Ping given host and output results in compact format 
:: %1 - host to ping
::
:_cping
Set PINGARGS=-n 8 -l 64 -f -4
For /F "tokens=* usebackq" %%a In ( `ping %PINGARGS% %1` ) Do (
         Echo "%%a" | FindStr /R ":.*=" >nul && (
           For /F "tokens=1-7 delims=,= " %%i In ("%%a") Do Set PSENT=%%k& Set PRCVD=%%m& Set PLOST=%%o
        )
         Echo "%%a" | FindStr /R "([0-9][0-9]*% " >nul && (
           For /F "tokens=1 delims=%%^( " %%i In ("%%a") Do Set PLOSS=%%i
        )
         Echo "%%a" | Find "loss" >nul && (
           For /F "tokens=1,2 delims=%%^(" %%i In ("%%a") Do Set PLOSS=%%j
        )
         Echo "%%a" | Find /V ":" | FindStr /R "=" >nul && (
           For /F "tokens=1-3 delims=," %%i In ("%%a") Do For /F "tokens=1-3" %%x In ("%%k") Do Set PAVG=%%z
        )
)

Call :_Echo [%TIME:~0,-3%] %1: 
If "%PLOSS%"=="100" (Echo not responding & GoTo :Eof)
If "%PSENT%"=="" ( Echo error parsing ping results )  Else Echo avg:%PAVG:ms=%ms lost:%PLOST%/%PSENT% (%PLOSS%%%)
GoTo :Eof



::
:: Echoes a given string without CRLF
::
:_Echo
        Set /P =%*< nul
Goto :Eof

::
:: resolve node region by ip
:: %1: ip
:_PrintRegion
  For /F "tokens=1,2 delims=." %%a In ("%1") Do Set IP=%%a.%%b 
  shift
:_PrLoop
        Echo %1 | FindStr "%IP%" && Goto :Eof
        Shift
        If Not %1.==. GoTo :_PrLoop
Goto :Eof

