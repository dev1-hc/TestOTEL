# PowerShell Script to Setup NGINX + OTEL Integration on Windows with WSL/Podman

Write-Host "🚀 NGINX + OpenTelemetry Integration Setup" -ForegroundColor Green
Write-Host ""

# Check if running in WSL or need to use WSL
$isWSL = $env:WSL_DISTRO_NAME -ne $null

if (-not $isWSL) {
    Write-Host "⚠️  This script needs to run in WSL or you need Podman Desktop on Windows" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Option 1: Run in WSL" -ForegroundColor Cyan
    Write-Host "  wsl bash ./quick_start.sh" -ForegroundColor White
    Write-Host ""
    Write-Host "Option 2: Use Podman Desktop" -ForegroundColor Cyan
    Write-Host "  1. Install Podman Desktop: https://podman-desktop.io/" -ForegroundColor White
    Write-Host "  2. Open WSL terminal in Podman Desktop" -ForegroundColor White
    Write-Host "  3. Navigate to project directory" -ForegroundColor White
    Write-Host "  4. Run: bash ./quick_start.sh" -ForegroundColor White
    Write-Host ""
    
    $response = Read-Host "Do you want to run the scripts in WSL now? (y/n)"
    if ($response -eq 'y' -or $response -eq 'Y') {
        Write-Host "🔄 Launching WSL..." -ForegroundColor Green
        
        # Get current directory in WSL format
        $currentPath = (Get-Location).Path
        $wslPath = $currentPath -replace '\\', '/' -replace 'D:', '/mnt/d' -replace 'C:', '/mnt/c'
        
        # Make scripts executable and run
        wsl bash -c "cd '$wslPath' && chmod +x quick_start.sh integrate_nginx_otel.sh OTEL/chainguard.sh && ./quick_start.sh"
    }
} else {
    Write-Host "✅ Running in WSL" -ForegroundColor Green
    
    # Make scripts executable
    bash -c "chmod +x quick_start.sh integrate_nginx_otel.sh OTEL/chainguard.sh"
    
    # Run setup
    bash -c "./quick_start.sh"
}

Write-Host ""
Write-Host "📚 After setup, test with:" -ForegroundColor Cyan
Write-Host "  wsl curl http://localhost" -ForegroundColor White
Write-Host "  wsl curl http://localhost/health" -ForegroundColor White
Write-Host ""
Write-Host "📊 View OTEL logs:" -ForegroundColor Cyan
Write-Host "  wsl podman logs -f otel-collector" -ForegroundColor White
