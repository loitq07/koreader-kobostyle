# PowerShell Script: Deploy Standalone E-Ink Dashboard to Kobo (NO KOREADER)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "Dang tim kiem may doc sach Kobo..." -ForegroundColor Cyan

# Find Kobo drive
$koboDrive = $null
$drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -notmatch '^[CD]:\\' }

foreach ($drive in $drives) {
    if (Test-Path (Join-Path $drive.Root ".kobo")) {
        $koboDrive = $drive.Root
        break
    }
}

if (-not $koboDrive) {
    $manualLetter = Read-Host "Khong tim thay tu dong. Vui long nhap ky tu o dia Kobo (vi du F)"
    if ($manualLetter) {
        $manualLetter = $manualLetter.Trim().TrimEnd(':')
        $testPath = "${manualLetter}:\"
        if (Test-Path $testPath) {
            $koboDrive = $testPath
        } else {
            Write-Host "[!] O dia khong ton tai." -ForegroundColor Red
            exit 1
        }
    } else {
        exit 1
    }
}

Write-Host "[+] Da tim thay o dia Kobo: $koboDrive" -ForegroundColor Green

# 1. Create .adds/kobo-dashboard/
$targetDir = Join-Path $koboDrive ".adds\kobo-dashboard"
if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
}

# 2. Copy scripts with Unix LF line endings
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$scripts = @("start_dashboard.sh", "stop_dashboard.sh", "show_log.sh", "dashboard.conf")

foreach ($s in $scripts) {
    $src = Join-Path $scriptDir $s
    if (Test-Path $src) {
        $content = Get-Content -Path $src -Raw
        [System.IO.File]::WriteAllText((Join-Path $targetDir $s), ($content -replace "`r`n", "`n"), $utf8NoBom)
        Write-Host "[*] Da sao chep script $s vao Kobo" -ForegroundColor Cyan
    }
}

# 3. Copy dashboard PNGs (Portrait & Landscape)
$pngFiles = @("dashboard.png", "dashboard_landscape.png", "dashboard_landscape_kobo.png")
foreach ($p in $pngFiles) {
    $src = Join-Path $scriptDir $p
    if (Test-Path $src) {
        Copy-Item -Path $src -Destination (Join-Path $targetDir $p) -Force
        Write-Host "[*] Da sao chep $p vao kobo-dashboard" -ForegroundColor Cyan
    }
}

# 4. Copy standalone FBInk ARM binary
$localFbink = Join-Path $scriptDir "fbink"
$targetFbink = Join-Path $targetDir "fbink"

if (Test-Path $localFbink) {
    Copy-Item -Path $localFbink -Destination $targetFbink -Force
    Write-Host "[+] Da chep binary FBInk ARM san sang thuc thi!" -ForegroundColor Green
} else {
    Write-Host "[!] Canh bao: Khong tim thay binary fbink cuc bo!" -ForegroundColor Yellow
}

# 5. Clean up and write NickelMenu config with Log viewer support
$nmDir = Join-Path $koboDrive ".adds\nm"
if (Test-Path $nmDir) {
    $nmFile = Join-Path $nmDir "dashboard"
    $nmContent = "menu_item:main:E-Ink Dashboard:cmd_spawn:quiet:exec /bin/sh /mnt/onboard/.adds/kobo-dashboard/start_dashboard.sh`nmenu_item:main:Xem Log Dashboard:cmd_output:2000:exec /bin/sh /mnt/onboard/.adds/kobo-dashboard/show_log.sh`nmenu_item:main:Tat Dashboard:cmd_spawn:quiet:exec /bin/sh /mnt/onboard/.adds/kobo-dashboard/stop_dashboard.sh`n"
    [System.IO.File]::WriteAllText($nmFile, $nmContent, $utf8NoBom)
    Write-Host "[+] Da cap nhat NickelMenu voi tinh nang 'Xem Log Dashboard' (cmd_output)!" -ForegroundColor Green
}

Write-Host ""
Write-Host "[V] Da cap nhat Dashboard va Cong cu xem Log thanh cong len Kobo!" -ForegroundColor Green
