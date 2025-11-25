#Requires AutoHotkey 2.0
#SingleInstance Force

DEBUG := false ; set to true for tooltip button state debugging

; Tested on:
; Edition       Windows 11 Home
; Version       24H2
; Installed on ‎ 8/‎26/‎2025
; OS build      26100.6899
; Experience    Windows Feature Experience Pack 1000.26100.253.0
;
; Running on:
; Lenovo Legion Go 8APU1
;
; Prior Steps:
; 1. Disable everything inside Game Bar app
; 2. Disable everything related to Game Bar in Settings,
;    including in System > System Components, as well as
;    not letting it run in background
; 3. Uninstall Game Bar:
;    3.1- Right-click on PowerShell and click Run as Administrator
;    3.2- Get-AppxPackage -AllUsers Microsoft.XboxGamingOverlay | Remove-AppxPackage
;    3.3- Get-AppxPackage -AllUsers Microsoft.XboxGameOverlay | Remove-AppxPackage
; 4. Cross your fingers?
;
; TODO:
; - tighten up the ms-gamebar window killer
; - fix the issue where this does not consistently bring up the Steam Overlay while a game is running

; The Xbox Guide button virtual keycode is "07", but this does not seem to work.
; For some reason this actually sends #^# instead of the virtual keycode for the
; Xbox Guide Button, but I'm keeping it here for posterity
;#g::Send("{vk07}")

; So instead let's emulate all the expected functionality manually
#g::SteamButton()

; Some notes about ways to programmatically control Steam
; C:\Program Files (x86)\Steam\steam.exe Opens Steam if not running, focuses Steam if running
; C:\Program Files (x86)\Steam\steam.exe -bigpicture Opens Steam in Big Picture mode, whether currently running or not
; steam://open/ Focuses Steam (if Steam is running)
; steam://open/bigpicture Opens Steam in Big Picture Mode (if Steam is already running)
; alt+enter Exits Big Picture Mode, back to regular Steam
; shift+tab Opens Steam overlay (during a game) or main menu (with Big Picture Mode in focus)
; ctrl+alt+1 Opens Steam main menu (with Big Picture Mode in focus)
; ctrl+alt+2 Opens Steam "Quick Access" menu (with Big Picture Mode in focus)
; also, when Steam is in Big Picture Mode, a background process called gameoverlayui.exe or gameoverlayui64.exe should be running

; Courtesy of Lexikos from https://www.autohotkey.com/boards/viewtopic.php?t=106254
Loop {
  tt := ''

  if (!state := XInputState(0)) {
    MsgBox 'No controller found; exiting...'

    ExitApp
  } else {
    tt .= state.wButtons

    if (WinExist("Run Steam?") and state) {
      switch state.wButtons {
        case "4096": ; "A" button (oversimplified)
          ControlClick("Button1", "Run Steam?")
        case "8192": ; "B" button (oversimplified)
          ControlClick("Button2", "Run Steam?")
      }
    }
  }

  tt .= "..."

;  if (WinExist("ahk_exe OpenWith.exe", "ms-gamebar")) { ; this should work, but it doesn't
  if (WinExist("Pick an app")) {
    tt .= " ms-gamebar window exists"
    WinClose("Pick an app")
;    WinClose("ahk_exe OpenWith.exe", "ms-gamebar") ; this should work, but it doesn't
  } else {
    tt .= " ms-gamebar window does not exist"
  }

  if (DEBUG) {
    ToolTip tt
  }

  sleep 100
}

; Also courtesy of Lexikos from https://www.autohotkey.com/boards/viewtopic.php?t=106254
#DllLoad XInput1_4.dll
XInputState(UserIndex) {
  xiState := Buffer(16)
  if err := DllCall("XInput1_4\XInputGetState", "uint", UserIndex, "ptr", xiState) {
    if err = 1167 ; ERROR_DEVICE_NOT_CONNECTED
      return 0
    throw OSError(err, -1)
  }

  return {
    wButtons: NumGet(xiState,  4, "UShort")
  }
}

OpenSteamCheck() {
  ; pop up confirmation box asking to run Steam
  ; controller "A" button works for "Yes"
  ; controller "B" button works for "No"
  result := MsgBox("
  (
    Steam is not running. Start it?
    (this message will disappear in 3 seconds)

    On your controller: A = Yes, B = No
  )", "Run Steam?", "YesNo Icon? Default2 T3")

  switch result {
    case "Yes": Run "C:\Program Files (x86)\Steam\steam.exe"
    case "No": ; do nothing
    case "Timeout": ; do nothing
    default: ; do nothing
  }

  return
}

SteamButton() {
  if (!ProcessExist("steam.exe")) {
    OpenSteamCheck()
  }

  if WinActive("Steam Big Picture Mode") {
    ; Steam is in Big Picture Mode, and is in the foreground
    ; Let's send ctrl+alt+1, which should open the SBPM main menu
    Send "^!1"
  } else if ((ProcessExist("gameoverlayui.exe") or ProcessExist("gameoverlayui64.exe")) and !WinActive("Steam Big Picture Mode")) {
    ; Steam has launched a game with the Overlay enabled
    ; FIXME: unfortuantely I still haven't figured out how to get this to consistently trigger the Overlay
    ; FIXME: this presses shift+tab in, say, Notepad, but it's ignored by Steam while a game is in the foreground, unless you spam the button
    ; workaround: map another button to press shift+tab in order to raise the Overlay
;    Send "+{Tab}"
;    Send "{Blind}+{Tab}"
;    SendInput "+{Tab}"
;    SendInput "{Blind}+{Tab}"
;    SendEvent "+{Tab}"
;    SendEvent "{Blind}+{Tab}"
  } else if WinExist("Steam Big Picture Mode") {
    ; Steam is in Big Picture Mode, but is in the background or minimised to the Taskbar
    ; Let's focus SBPM and open the main menu
    WinActivate("Steam Big Picture Mode")
    Send "^!1"
  } else if WinActive("Steam") {
    ; Steam is in normal mode, and is in the foreground
    ; Let's open Steam in Big Picture Mode
    Run "steam://open/bigpicture"
  } else if WinExist("Steam") {
    ; Steam is in normal mode, but is in the background or minimised to the Taskbar
    ; Let's focus the Steam window
    WinActivate("Steam")
  } else if ProcessExist("steamwebhelper.exe") {
    ; Steam doesn't have a window, but is running in the background while minimized to the System Tray
    ; Let's run Steam as a way of telling the existing process to spawn a new window
    Run "C:\Program Files (x86)\Steam\steam.exe"
  } else {
    ; unknown state, do nothing
  }
}