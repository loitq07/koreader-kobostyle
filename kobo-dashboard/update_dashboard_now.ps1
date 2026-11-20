# Run this script to regenerate dashboard.png immediately with the latest Hanoi weather and T3 Agent Quotas

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$genScript = Join-Path $scriptDir "generate_dashboard.py"

Write-Host "Dang tao Dashboard E-Ink moi nhat (Space Grotesk Bold + Phosphor Light + T3 Quotas)..." -ForegroundColor Cyan
python $genScript

if ($LASTEXITCODE -eq 0) {
    Write-Host "[V] Da tao xong cac anh Dashboard thanh cong!" -ForegroundColor Green

    # Check if Kobo is connected and sync immediately
    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -notmatch '^[CD]:\\' }
    foreach ($drive in $drives) {
        $target = Join-Path $drive.Root ".adds\kobo-dashboard"
        if (Test-Path $target) {
            Write-Host "[*] Phat hien Kobo tai $($drive.Root), dang dong bo anh sang Kobo..." -ForegroundColor Cyan
            Copy-Item (Join-Path $scriptDir "dashboard.png") (Join-Path $target "dashboard.png") -Force
            Copy-Item (Join-Path $scriptDir "dashboard_landscape.png") (Join-Path $target "dashboard_landscape.png") -Force
            Copy-Item (Join-Path $scriptDir "dashboard_landscape_kobo.png") (Join-Path $target "dashboard_landscape_kobo.png") -Force
            Write-Host "[+] Da dong bo anh sang Kobo hoan tat!" -ForegroundColor Green
            break
        }
    }
} else {
    Write-Host "[!] Co loi xay ra khi tao anh." -ForegroundColor Red
}
