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

; Uncomment this whole loop to debug with a tooltip
; Courtesy of Lexikos from https://www.autohotkey.com/boards/viewtopic.php?t=106254
Loop {
  tt := ''

  if (!state := XInputState(0)) {
    MsgBox 'No controller found; exiting...'

    ExitApp
  } else {
    tt .= state.wButtonsMap.ToJSON()

; FIXME: All that overkill and it still doesn't do what I intended...
;    if (WinExist("Run Steam?") and state and state.wButtonsMap.a) {
;      ControlClick("Button1", "Run Steam?")
;    }
;
;    if (WinExist("Run Steam?") and state and state.wButtonsMap.b) {
;      ControlClick("Button2", "Run Steam?")
;    }

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

; FIXME: This is absolute overkill for this simple use-case, but it was a fun exercise...
class XInputButtonsMap {
  static propsArray := [ 'a', 'b', 'x', 'y', 'lb', 'rb', 'b6', 'b7', 'back', 'menu', 'ls', 'rs', 'up', 'down', 'left', 'right', 'guide' ]

  static new() {
    throw
  }

  static __new() {
    for _i, v in this.propsArray {
      this.defineprop(v, {
        value: false
      })
    }
  }

  ; id comes from how gamepad-tester and other web-based tools map the Guide button
  ; some sources say the Guide button is not exposed as part of XInput
  ; other sources say the Guide button is at offset 0x0400 (1024), but that doesn't seem to work with AHKv2
  static update(btnStateBinString) { ;  decimal:    id  (name):             ; 16-bit binary:
    this.a     := (btnStateBinString &  4096 > 0) ; B0  (A)                 ; 0b0001000000000000
    this.b     := (btnStateBinString &  8192 > 0) ; B1  (B)                 ; 0b0010000000000000
    this.x     := (btnStateBinString & 16384 > 0) ; B2  (X)                 ; 0b0100000000000000
    this.y     := (btnStateBinString & 32768 > 0) ; B3  (Y)                 ; 0b1000000000000000
    this.lb    := (btnStateBinString &   256 > 0) ; B4  (Left Bumper)       ; 0b0000000100000000
    this.rb    := (btnStateBinString &   512 > 0) ; B5  (Right Bumper)      ; 0b0000001000000000
    this.back  := (btnStateBinString &    32 > 0) ; B8  (Back)              ; 0b0000000000100000
    this.menu  := (btnStateBinString &    16 > 0) ; B9  (Menu)              ; 0b0000000000010000
    this.ls    := (btnStateBinString &    64 > 0) ; B10 (Left Stick Click)  ; 0b0000000001000000
    this.rs    := (btnStateBinString &   128 > 0) ; B11 (Right Stick Click) ; 0b0000000010000000
    this.up    := (btnStateBinString &     1 > 0) ; B12 (D-Pad Up)          ; 0b0000000000000001
    this.down  := (btnStateBinString &     2 > 0) ; B13 (D-Pad Down)        ; 0b0000000000000010
    this.left  := (btnStateBinString &     4 > 0) ; B14 (D-Pad Left)        ; 0b0000000000000100
    this.right := (btnStateBinString &     8 > 0) ; B15 (D-Pad Right)       ; 0b0000000000001000

    ; these two show up in gamepad-tester.com but do not "light up" when any button is pressed:
    this.b6    := false                           ; B6  (Unknown)           ; 0b????????????????
    this.b7    := false                           ; B7  (Unknown)           ; 0b????????????????
    this.guide := false                           ; B16 (Unknown)           ; 0b????????????????
  }

  static formatStringForIndex(arr, i) {
    if (i < arr.length) {
      return '"{1}": {2}, '
    } else {
      return '"{1}": {2}'
    }
  }

  static ToJSON() {
    jsonFormattedOutput := '{ '

    for i, v in this.propsArray {
      jsonFormattedOutput .= Format(this.formatStringForIndex(this.propsArray, i), v, this.GetOwnPropDesc(v).Value)
    }

    return jsonFormattedOutput . ' }'
  }
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
  wButtons := NumGet(xiState,  4, "UShort")
  XInputButtonsMap.update(wButtons)
  return {
    dwPacketNumber: NumGet(xiState,  0, "UInt"),
    wButtons:       wButtons,
    wButtonsMap:    XInputButtonsMap,
    bLeftTrigger:   NumGet(xiState,  6, "UChar"),
    bRightTrigger:  NumGet(xiState,  7, "UChar"),
    sThumbLX:       NumGet(xiState,  8, "Short"),
    sThumbLY:       NumGet(xiState, 10, "Short"),
    sThumbRX:       NumGet(xiState, 12, "Short"),
    sThumbRY:       NumGet(xiState, 14, "Short"),
  }
}

; More of my code below
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