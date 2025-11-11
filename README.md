# Scripts
Collection of small scripts. This repository contains a Windows PowerShell script that displays a persistent on-screen indicator while the webcam is in use.

## camIndi.ps1 — Camera-in-use indicator for Windows

`camIndi.ps1` monitors the system webcam and shows a small always-on-top desktop indicator while the camera is being used. The indicator automatically hides when the camera is no longer in use.

Key behaviours:
- Uses Windows MediaCapture initialization to detect exclusive camera usage.
- Shows a compact, borderless WinForms window near the taskbar while the camera is in use.
- Relaunches itself in STA mode if needed (the script prefers an STA PowerShell process).

---

## Requirements
- Windows 11 (or Windows 10 with the appropriate WinRT APIs available).
- PowerShell running on the Windows host (not WSL). The script works best in a Windows PowerShell / PowerShell x64 session. It will attempt to relaunch itself with the `-STA` flag when necessary.
- No admin rights are strictly required for normal monitoring, but creating system-wide scheduled tasks or changing Execution Policy may require admin privileges.

## Files
- `camIndi.ps1` — the monitor script (placed at the repository root).

## Quick manual run
1. Open PowerShell (use the 64-bit Windows PowerShell / PowerShell x64).
2. Run the script using the `-STA` flag (the script will relaunch into STA if necessary). Example:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -STA -File "C:\path\to\camIndi.ps1"
```

Notes:
- `-ExecutionPolicy Bypass` allows the script to run without changing your system policy permanently. If you prefer, you can set an appropriate execution policy (for example, `RemoteSigned`) with administrator consent.
- If the script can't access the WinRT `MediaCapture` type it may print a message and treat the camera as "not in use". See Troubleshooting below.

## Run persistently (recommended options)
You probably want the monitor to start automatically each time you log on. Two easy options are described below.

### Option A — Startup folder (per-user, simple)
1. Create a shortcut in your user's Startup folder: `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\`.
2. Set the shortcut Target to:

```text
powershell -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "C:\path\to\camIndi.ps1"
```

This will run the script when you sign in. Use `-WindowStyle Hidden` to avoid an extra console window appearing. Because the indicator is a GUI overlay, the process must run in the interactive user session (so the shortcut approach is appropriate).

### Option B — Task Scheduler (recommended when you want finer control)
Create a scheduled task that runs the script at logon. Important: to display the on-screen indicator you must run the task in the interactive user session, so choose "Run only when user is logged on." Steps:

1. Open Task Scheduler and select "Create Task...".
2. On the "General" tab:
	 - Give it a name like `camIndi`.
	 - Choose "Run only when user is logged on" (so the UI can appear on the desktop).
3. On the "Triggers" tab: add a trigger "At log on" for the target user.
4. On the "Actions" tab: add a new action
	 - Program/script: `powershell.exe`
	 - Add arguments: `-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "C:\path\to\camIndi.ps1"`
5. Optionally enable "Run with highest privileges" if you run into permission issues when creating other supporting tasks — usually not required for this script.
6. Save the task.

To stop/disable the monitor later, disable or delete the scheduled task, or end the running `powershell.exe` task in Task Manager.

### Running for all users / as a service
Because the script shows an interactive overlay window it must run in a user's session. Running it as a system service (no interactive desktop) will not display the indicator. For an "all users" behaviour consider deploying the same startup task or shortcut to each account or using a login script/GPO in enterprise environments.

## Stopping the script
- If started manually: close the console window or press Ctrl+C in the console that launched it.
- If started via Startup shortcut: sign out or remove the shortcut.
- If started via Task Scheduler: open Task Scheduler and End or Disable the task, or use Task Manager to end the `powershell.exe` process.

## Troubleshooting
- "MediaCapture type not available" or initialization errors:
	- Make sure you're running on a supported Windows host (not WSL) and that PowerShell is the 64-bit Windows build.
	- The script will try to relaunch itself in STA mode; allow it a few seconds on first start.
	- If you see repeated failures, check camera drivers and Windows Camera privacy settings (Settings → Privacy & security → Camera) and confirm apps are allowed to use the camera.
- Indicator never appears even when camera in use:
	- Ensure the script is running in the same interactive user session as the application using the camera.
	- If you used Task Scheduler, make sure the task is set to "Run only when user is logged on" so UI can be shown.
- ExecutionPolicy errors:
	- Either use `-ExecutionPolicy Bypass` on the scheduled action/shortcut, or set an appropriate policy with `Set-ExecutionPolicy` if you prefer.

## Privacy & Security
This script only detects whether a camera device appears to be in use and displays a local UI indicator. It does not transmit or log camera frames or audio. Use the script at your own discretion — in managed environments follow your organization's security policy.

## Optional enhancements
- Add a tray icon and context menu (start/stop/exit) — the current script can be extended to add a notify icon.
- Add logging, hotkeys, or a configuration file to control placement and style of the indicator.

## License
This repository is provided as-is. Modify and use it under your preferred terms. No warranty.

---

If you'd like, I can also provide a ready-made Task Scheduler XML export, a simple installer that creates the Startup shortcut for you, or add a tray icon to the script so you can easily stop/start it from the notification area.
