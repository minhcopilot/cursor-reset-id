# Script to fix config directory permissions
# Run this script as Administrator if needed

$Theme = @{
    Primary   = 'Cyan'
    Success   = 'Green'
    Warning   = 'Yellow'
    Error     = 'Red'
    Info      = 'White'
}

function Write-Styled {
    param (
        [string]$Message,
        [string]$Color = $Theme.Info,
        [string]$Prefix = ""
    )
    $symbol = switch ($Color) {
        $Theme.Success { "[OK]" }
        $Theme.Error   { "[X]" }
        $Theme.Warning { "[!]" }
        default        { "[*]" }
    }
    
    $output = if ($Prefix) { "$symbol $Prefix :: $Message" } else { "$symbol $Message" }
    Write-Host $output -ForegroundColor $Color
}

Write-Styled "Fixing config directory permissions..." -Color $Theme.Primary -Prefix "Fix"

try {
    $documentsPath = [Environment]::GetFolderPath("MyDocuments")
    if (-not $documentsPath -or -not (Test-Path $documentsPath)) {
        Write-Styled "Documents folder not found, using user profile" -Color $Theme.Warning -Prefix "Warning"
        $documentsPath = [Environment]::GetFolderPath("UserProfile")
    }
    
    $configDir = Join-Path $documentsPath ".cursor-free-vip"
    $configFile = Join-Path $configDir "config.ini"
    
    Write-Styled "Config directory: $configDir" -Color $Theme.Info -Prefix "Info"
    
    # Create directory if it doesn't exist
    if (-not (Test-Path $configDir)) {
        Write-Styled "Creating config directory..." -Color $Theme.Primary -Prefix "Create"
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        Write-Styled "Config directory created" -Color $Theme.Success -Prefix "Success"
    }
    
    # Take ownership
    Write-Styled "Taking ownership of config directory..." -Color $Theme.Primary -Prefix "Ownership"
    $takeown = Start-Process -FilePath "takeown.exe" -ArgumentList "/F", "`"$configDir`"", "/R", "/D", "Y" -Wait -NoNewWindow -PassThru
    
    if ($takeown.ExitCode -eq 0) {
        Write-Styled "Ownership taken successfully" -Color $Theme.Success -Prefix "Success"
    } else {
        Write-Styled "Warning: takeown exit code: $($takeown.ExitCode)" -Color $Theme.Warning -Prefix "Warning"
    }
    
    # Grant full control to current user
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    Write-Styled "Granting full control to: $currentUser" -Color $Theme.Primary -Prefix "Permissions"
    $icacls = Start-Process -FilePath "icacls.exe" -ArgumentList "`"$configDir`"", "/grant", "${currentUser}:F", "/T" -Wait -NoNewWindow -PassThru
    
    if ($icacls.ExitCode -eq 0) {
        Write-Styled "Permissions granted successfully" -Color $Theme.Success -Prefix "Success"
    } else {
        Write-Styled "Warning: icacls exit code: $($icacls.ExitCode)" -Color $Theme.Warning -Prefix "Warning"
    }
    
    # Remove read-only attribute if config file exists
    if (Test-Path $configFile) {
        Write-Styled "Removing read-only attribute from config file..." -Color $Theme.Primary -Prefix "Attributes"
        try {
            $file = Get-Item $configFile
            $file.IsReadOnly = $false
            $file.Attributes = $file.Attributes -band (-bnot [System.IO.FileAttributes]::ReadOnly)
            Write-Styled "Read-only attribute removed" -Color $Theme.Success -Prefix "Success"
        } catch {
            Write-Styled "Could not remove read-only attribute: $($_.Exception.Message)" -Color $Theme.Warning -Prefix "Warning"
        }
    }
    
    # Test write access
    Write-Styled "Testing write access..." -Color $Theme.Primary -Prefix "Test"
    try {
        $testFile = Join-Path $configDir ".write_test"
        $null = New-Item -ItemType File -Path $testFile -Force -ErrorAction Stop
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
        Write-Styled "Write access test passed!" -Color $Theme.Success -Prefix "Success"
        Write-Styled "Config directory permissions fixed successfully!" -Color $Theme.Success -Prefix "Complete"
    } catch {
        Write-Styled "Write access test failed: $($_.Exception.Message)" -Color $Theme.Error -Prefix "Error"
        Write-Styled "You may need to run this script as Administrator" -Color $Theme.Warning -Prefix "Warning"
    }
    
} catch {
    Write-Styled "Error: $($_.Exception.Message)" -Color $Theme.Error -Prefix "Error"
    Write-Styled "Please run this script as Administrator" -Color $Theme.Warning -Prefix "Warning"
}

Write-Host "`nPress any key to exit..." -ForegroundColor $Theme.Info
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')

