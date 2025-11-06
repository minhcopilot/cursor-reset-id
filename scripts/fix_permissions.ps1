# Script to fix Cursor Free VIP config permissions
# This script can be run independently on client machines
# Run as Administrator for best results

$ErrorActionPreference = "Continue"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Cursor Free VIP - Fix Config Permissions" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

try {
    # Get Documents path
    $documentsPath = [Environment]::GetFolderPath("MyDocuments")
    if (-not $documentsPath -or -not (Test-Path $documentsPath)) {
        Write-Host "[!] Documents folder not found, using user profile" -ForegroundColor Yellow
        $documentsPath = [Environment]::GetFolderPath("UserProfile")
    }
    
    $configDir = Join-Path $documentsPath ".cursor-free-vip"
    $configFile = Join-Path $configDir "config.ini"
    
    Write-Host "[*] Config directory: $configDir" -ForegroundColor White
    Write-Host ""
    
    # Create directory if it doesn't exist
    if (-not (Test-Path $configDir)) {
        Write-Host "[*] Creating config directory..." -ForegroundColor Cyan
        try {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
            Write-Host "[OK] Config directory created" -ForegroundColor Green
        } catch {
            Write-Host "[X] Failed to create directory: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "[!] Try running this script as Administrator" -ForegroundColor Yellow
            exit 1
        }
    } else {
        Write-Host "[OK] Config directory exists" -ForegroundColor Green
    }
    
    # Check if running as admin
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if ($isAdmin) {
        Write-Host "[OK] Running as Administrator" -ForegroundColor Green
        Write-Host ""
        
        # Take ownership
        Write-Host "[*] Taking ownership of config directory..." -ForegroundColor Cyan
        $takeownArgs = @("/F", "`"$configDir`"", "/R", "/D", "Y")
        $takeown = Start-Process -FilePath "takeown.exe" -ArgumentList $takeownArgs -Wait -NoNewWindow -PassThru -ErrorAction SilentlyContinue
        
        if ($takeown -and $takeown.ExitCode -eq 0) {
            Write-Host "[OK] Ownership taken successfully" -ForegroundColor Green
        } else {
            Write-Host "[!] Warning: Could not take ownership (this may be normal)" -ForegroundColor Yellow
        }
        
        # Grant full control to current user
        $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        Write-Host "[*] Granting full control to: $currentUser" -ForegroundColor Cyan
        $icaclsArgs = @("`"$configDir`"", "/grant", "${currentUser}:F", "/T")
        $icacls = Start-Process -FilePath "icacls.exe" -ArgumentList $icaclsArgs -Wait -NoNewWindow -PassThru -ErrorAction SilentlyContinue
        
        if ($icacls -and $icacls.ExitCode -eq 0) {
            Write-Host "[OK] Permissions granted successfully" -ForegroundColor Green
        } else {
            Write-Host "[!] Warning: Could not grant permissions" -ForegroundColor Yellow
        }
    } else {
        Write-Host "[!] Not running as Administrator" -ForegroundColor Yellow
        Write-Host "[!] Some operations may fail. Try running as Administrator for best results." -ForegroundColor Yellow
        Write-Host ""
        
        # Try to set permissions without admin
        Write-Host "[*] Attempting to set permissions (non-admin mode)..." -ForegroundColor Cyan
        try {
            $acl = Get-Acl $configDir
            $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
            $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($currentUser, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
            $acl.SetAccessRule($accessRule)
            Set-Acl $configDir $acl
            Write-Host "[OK] Permissions set successfully" -ForegroundColor Green
        } catch {
            Write-Host "[!] Could not set permissions: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    
    # Remove read-only attribute if config file exists
    if (Test-Path $configFile) {
        Write-Host "[*] Removing read-only attribute from config file..." -ForegroundColor Cyan
        try {
            $file = Get-Item $configFile
            $file.IsReadOnly = $false
            $file.Attributes = $file.Attributes -band (-bnot [System.IO.FileAttributes]::ReadOnly)
            Write-Host "[OK] Read-only attribute removed" -ForegroundColor Green
        } catch {
            Write-Host "[!] Could not remove read-only attribute: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    
    # Test write access
    Write-Host ""
    Write-Host "[*] Testing write access..." -ForegroundColor Cyan
    try {
        $testFile = Join-Path $configDir ".write_test_$(Get-Random)"
        $null = New-Item -ItemType File -Path $testFile -Force -ErrorAction Stop
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
        Write-Host "[OK] Write access test PASSED!" -ForegroundColor Green
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "  SUCCESS! Permissions fixed!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "You can now run Cursor Free VIP without permission errors." -ForegroundColor White
    } catch {
        Write-Host "[X] Write access test FAILED: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Red
        Write-Host "  FAILED! Please try:" -ForegroundColor Red
        Write-Host "========================================" -ForegroundColor Red
        Write-Host ""
        Write-Host "1. Run this script as Administrator (Right-click -> Run as Administrator)" -ForegroundColor Yellow
        Write-Host "2. Or manually run these commands in PowerShell (as Admin):" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "   takeown.exe /F `"$configDir`" /R /D Y" -ForegroundColor Cyan
        Write-Host "   icacls.exe `"$configDir`" /grant ${env:USERNAME}:F /T" -ForegroundColor Cyan
        Write-Host ""
    }
    
} catch {
    Write-Host ""
    Write-Host "[X] Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "[!] Please run this script as Administrator" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "Press any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')

