# ==============================================================================
# Smart Hotel System - Collect Binaries Script (collect_bins.ps1)
# ==============================================================================

$projects = @("room_terminal", "front_desk_terminal", "floor_controller")
$base_dir = $PSScriptRoot | Split-Path -Parent
$output_dir = Join-Path -Path $base_dir -ChildPath "output"
$firmwares_dir = Join-Path -Path $output_dir -ChildPath "firmwares"
$map_dir = Join-Path -Path $output_dir -ChildPath "map_files"

if (!(Test-Path -Path $firmwares_dir)) { New-Item -ItemType Directory -Force -Path $firmwares_dir | Out-Null }
if (!(Test-Path -Path $map_dir)) { New-Item -ItemType Directory -Force -Path $map_dir | Out-Null }

$timestamp = Get-Date -Format "yyyyMMdd_HHmm"

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Extracting firmwares to output/ directory..." -ForegroundColor Cyan

foreach ($project in $projects) {
    $build_dir = Join-Path -Path $base_dir -ChildPath "$project\build"
    
    if (Test-Path $build_dir) {
        Write-Host "[+] Processing project: $project" -ForegroundColor Green
        
        $app_bin = Join-Path -Path $build_dir -ChildPath "$project.bin"
        $map_file = Join-Path -Path $build_dir -ChildPath "$project.map"
        $elf_file = Join-Path -Path $build_dir -ChildPath "$project.elf"
        
        $boot_bin = Join-Path -Path $build_dir -ChildPath "bootloader\bootloader.bin"
        $pt_bin = Join-Path -Path $build_dir -ChildPath "partition_table\partition-table.bin"
        
        $prefix = "${project}_${timestamp}"
        
        if (Test-Path $app_bin) { Copy-Item -Path $app_bin -Destination (Join-Path $firmwares_dir "${prefix}_app.bin") }
        if (Test-Path $boot_bin) { Copy-Item -Path $boot_bin -Destination (Join-Path $firmwares_dir "${prefix}_bootloader.bin") }
        if (Test-Path $pt_bin) { Copy-Item -Path $pt_bin -Destination (Join-Path $firmwares_dir "${prefix}_partition_table.bin") }
        
        if (Test-Path $map_file) { Copy-Item -Path $map_file -Destination (Join-Path $map_dir "${prefix}.map") }
        if (Test-Path $elf_file) { Copy-Item -Path $elf_file -Destination (Join-Path $map_dir "${prefix}.elf") }
        
    } else {
        Write-Host "[-] Skipping unbuilt project: $project" -ForegroundColor Yellow
    }
}

Write-Host "Extraction complete! Check /output directory." -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Cyan
