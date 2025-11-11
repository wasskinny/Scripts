# Continuous webcam-in-use monitor for Windows 11.
# Run in an STA PowerShell process (the script will relaunch itself with -STA if needed).
# Requires PowerShell running on the Windows host (not in WSL).

Add-Type -AssemblyName System.Windows.Forms, System.Drawing

# Relaunch in STA if current thread is not STA
if ([System.Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    Write-Host "Restarting in STA mode..."
    $ps = (Get-Command powershell).Source
    $args = "-NoProfile -ExecutionPolicy Bypass -STA -File `"$PSCommandPath`""
    Start-Process -FilePath $ps -ArgumentList $args -WindowStyle Hidden
    exit
}

# Create lightweight always-on-top indicator window
function New-IndicatorWindow {
    $form = New-Object System.Windows.Forms.Form
    $form.FormBorderStyle = 'None'
    $form.ShowInTaskbar = $false
    $form.TopMost = $true
    $form.StartPosition = 'Manual'
    $form.Width = 160
    $form.Height = 40
    $form.BackColor = [System.Drawing.Color]::FromArgb(200,20,20,20)
    $form.Opacity = 0.85
    $form.Padding = '6'
    $form.ToolTipText = 'Camera in use'

    $label = New-Object System.Windows.Forms.Label
    $label.AutoSize = $false
    $label.TextAlign = 'MiddleLeft'
    $label.Dock = 'Fill'
    $label.ForeColor = [System.Drawing.Color]::White
    $label.Font = New-Object System.Drawing.Font("Segoe UI",10,[System.Drawing.FontStyle]::Bold)
    $label.Text = "  ● Camera in use"
    $label.Padding = '6,6,6,6'

    # draw red dot
    $bmp = New-Object System.Drawing.Bitmap 16,16
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)
    $brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(230,50,50))
    $g.FillEllipse($brush,0,0,15,15)
    $g.Dispose()
    $icon = [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
    $label.Image = $bmp
    $label.ImageAlign = 'MiddleLeft'

    $form.Controls.Add($label)

    # position near bottom-right of primary screen, above taskbar
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $form.Location = New-Object System.Drawing.Point (($screen.Right - $form.Width - 10), ($screen.Bottom - $form.Height - 10))

    return $form
}

$indicator = New-IndicatorWindow
$indicatorVisible = $false

# Try to instantiate MediaCapture to test camera availability
function Test-CameraInUse {
    try {
        # Load MediaCapture WinRT type
        $mcType = [Windows.Media.Capture.MediaCapture, Windows.Media.Capture, ContentType=WindowsRuntime]
        if (-not $mcType) { throw "MediaCapture type not available." }

        $mc = New-Object Windows.Media.Capture.MediaCapture
        $settings = New-Object Windows.Media.Capture.MediaCaptureInitializationSettings
        $settings.StreamingCaptureMode = [Windows.Media.Capture.StreamingCaptureMode]::Video

        # InitializeAsync returns an IAsyncAction / IAsyncOperation - wait on it
        $initTask = $mc.InitializeAsync($settings)
        $initTask.AsTask().Wait(3000)  # 3s timeout
        # If succeeded, camera is available (not in use)
        $mc.Close()
        $mc = $null
        return $false
    } catch {
        # HResult 0x80070020 (-2147024864) commonly indicates device is in use.
        $hr = $null
        if ($_.Exception -ne $null) { $hr = $_.Exception.HResult } else { $hr = $_.HResult }
        if ($hr -eq -2147024864 -or $_.Exception.Message -match "in use" -or $_.Exception.Message -match "device is in use") {
            return $true
        }
        # Some other failures (no camera, permissions) are treated as "not in use".
        return $false
    }
}

# Optional fallback: detect known processes that commonly use camera
$commonCameraProcesses = @('Teams', 'Zoom', 'ZoomMeeting', 'GoogleDriveFS', 'Slack', 'CiscoWebex', 'obs64', 'obs32', 'camera', 'msedge', 'chrome', 'brave', 'firefox', 'SkypeApp')

function Test-KnownCameraProcess {
    foreach ($p in $commonCameraProcesses) {
        if (Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match "^$p$" }) {
            return $true
        }
    }
    return $false
}

# Main loop: poll every 1s (adjust as desired)
$pollInterval = 1
Write-Host "Camera monitor running. Press Ctrl+C to stop."

# Run WinForms message loop on separate thread to keep UI responsive
$uiThread = [System.Threading.Thread]{
    param($form)
    [System.Windows.Forms.Application]::Run($form)
}.Create([ref]$indicator)

$uiThread.IsBackground = $true
$uiThread.SetApartmentState([System.Threading.ApartmentState]::STA)
$uiThread.Start($indicator)

try {
    while ($true) {
        $inUse = $false
        # primary detection via MediaCapture
        $inUse = Test-CameraInUse

        # if MediaCapture couldn't detect a device at all, fallback to process scan
        if (-not $inUse) {
            # quick process-based heuristic (optional)
            if (Test-KnownCameraProcess) { $inUse = $true }
        }

        if ($inUse -and -not $indicatorVisible) {
            # show indicator
            $indicator.Invoke((action{$indicator.Show()})) | Out-Null
            $indicatorVisible = $true
        } elseif (-not $inUse -and $indicatorVisible) {
            $indicator.Invoke((action{$indicator.Hide()})) | Out-Null
            $indicatorVisible = $false
        }

        Start-Sleep -Seconds $pollInterval
    }
} catch [System.OperationCanceledException] {
    # exit gracefully
} catch {
    Write-Host "Monitor stopped: $_"
} finally {
    if ($indicator -ne $null) {
        $indicator.Invoke((action{$indicator.Close()})) | Out-Null
    }
    exit
}