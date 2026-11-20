# PowerShell script to deploy E-Ink UI (eink-ui.com spec) to connected Kobo e-reader

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourcePluginDir = Join-Path $scriptDir "kobostyle.koplugin"

if (-not (Test-Path $sourcePluginDir)) {
    Write-Host "[!] Khong tim thay thu muc plugin tai: $sourcePluginDir" -ForegroundColor Red
    exit 1
}

Write-Host "Dang tim kiem thiet bi Kobo duoc ket noi..." -ForegroundColor Cyan

# Find drives that have .kobo or .adds/koreader
$koboDrive = $null
$drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -notmatch '^[CD]:\\' }

foreach ($drive in $drives) {
    $koboMarker = Join-Path $drive.Root ".kobo"
    $koreaderDir = Join-Path $drive.Root ".adds\koreader"
    if ((Test-Path $koboMarker) -or (Test-Path $koreaderDir)) {
        $koboDrive = $drive.Root
        break
    }
}

if (-not $koboDrive) {
    Write-Host "[?] Khong tu dong nhan dien duoc o dia Kobo." -ForegroundColor Yellow
    $manualLetter = Read-Host "Vui long nhap ky tu o dia Kobo cua ban (vi du E hoac F)"
    if ($manualLetter) {
        $manualLetter = $manualLetter.Trim().TrimEnd(':')
        $testPath = "${manualLetter}:\"
        if (Test-Path $testPath) {
            $koboDrive = $testPath
        } else {
            Write-Host "[!] O dia $testPath khong ton tai." -ForegroundColor Red
            exit 1
        }
    } else {
        exit 1
    }
}

Write-Host "[+] Da tim thay o dia Kobo: $koboDrive" -ForegroundColor Green

# 1. Copy plugin folder
$targetPluginsDir = Join-Path $koboDrive ".adds\koreader\plugins"
if (-not (Test-Path $targetPluginsDir)) {
    Write-Host "[*] Dang tao thu muc plugins tai: $targetPluginsDir" -ForegroundColor Gray
    New-Item -ItemType Directory -Path $targetPluginsDir -Force | Out-Null
}

$destPluginDir = Join-Path $targetPluginsDir "kobostyle.koplugin"
Write-Host "[*] Dang sao chep $sourcePluginDir -> $destPluginDir..." -ForegroundColor Cyan
Copy-Item -Path $sourcePluginDir -Destination $destPluginDir -Recurse -Force

# 2. Map Phosphor icons to system-wide .adds/koreader/icons/
$userIconsDir = Join-Path $koboDrive ".adds\koreader\icons"
if (-not (Test-Path $userIconsDir)) {
    New-Item -ItemType Directory -Path $userIconsDir -Force | Out-Null
}

$iconMapping = @{
    "arrow-left.svg" = @("back.top.svg", "chevron.left.svg", "appbar.filebrowser.svg")
    "magnifying-glass.svg" = @("appbar.search.svg")
    "bookmark-simple.svg" = @("bookmark.svg")
    "list-bullets.svg" = @("book.opened.svg")
    "text-aa.svg" = @("appbar.textsize.svg")
    "sun.svg" = @("appbar.contrast.svg")
    "navigation-arrow.svg" = @("appbar.navigation.svg")
    "dots-three-vertical.svg" = @("appbar.menu.svg")
    "house.svg" = @("home.svg")
    "chart-bar.svg" = @("statistics.svg")
    "book-open.svg" = @("book.svg")
}

Write-Host "[*] Dang cai dat Phosphor Icons vao he thong KOReader (.adds/koreader/icons)..." -ForegroundColor Cyan
foreach ($srcIcon in $iconMapping.Keys) {
    $srcPath = Join-Path $sourcePluginDir "icons\$srcIcon"
    if (Test-Path $srcPath) {
        foreach ($targetIcon in $iconMapping[$srcIcon]) {
            Copy-Item -Path $srcPath -Destination (Join-Path $userIconsDir $targetIcon) -Force
        }
    }
}

# 3. Configure Mihon 3-column Cover Grid in settings.reader.lua
$settingsFile = Join-Path $koboDrive ".adds\koreader\settings.reader.lua"
if (Test-Path $settingsFile) {
    Write-Host "[*] Dang cau hinh luoi bia 3 cot kieu Mihon trong settings.reader.lua..." -ForegroundColor Cyan
    $cfg = Get-Content -Path $settingsFile -Raw
    if ($cfg -notmatch '\["filemanager_display_mode"\]') {
        $cfg = $cfg -replace '(?m)^return \{', "return {`r`n    [`"filemanager_display_mode`"] = `"mosaic_image`","
    } else {
        $cfg = $cfg -replace '(?m)\["filemanager_display_mode"\] = "[^"]+"', '["filemanager_display_mode"] = "mosaic_image"'
    }
    if ($cfg -notmatch '\["nb_cols_portrait"\]') {
        $cfg = $cfg -replace '(?m)^return \{', "return {`r`n    [`"nb_cols_portrait`"] = 3,"
    }
    if ($cfg -notmatch '\["nb_rows_portrait"\]') {
        $cfg = $cfg -replace '(?m)^return \{', "return {`r`n    [`"nb_rows_portrait`"] = 3,"
    }
    [System.IO.File]::WriteAllText($settingsFile, $cfg, [System.Text.Encoding]::UTF8)
}

Write-Host "[V] Cai dat hoan tat! Giao dien E-Ink UI (eink-ui.com) & luoi bia 3 cot Mihon da san sang tren Kobo." -ForegroundColor Green
