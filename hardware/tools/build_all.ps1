# ==============================================================================
# Smart Hotel System - Build All Script (build_all.ps1)
# ==============================================================================

$projects = @("room_terminal", "front_desk_terminal", "floor_controller")
$base_dir = $PSScriptRoot | Split-Path -Parent

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Starting full rebuild... (ESP-IDF environment required)" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan

foreach ($project in $projects) {
    $project_path = Join-Path -Path $base_dir -ChildPath $project
    if (Test-Path $project_path) {
        Write-Host "`n[+] Building project: $project" -ForegroundColor Green
        Set-Location $project_path
        
        idf.py build
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[-] Build failed: $project, aborting." -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "[-] Directory not found: $project" -ForegroundColor Yellow
    }
}

Write-Host "`n======================================" -ForegroundColor Cyan
Write-Host "All projects built successfully! Run .\collect_bins.ps1 to extract firmwares." -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Cyan
