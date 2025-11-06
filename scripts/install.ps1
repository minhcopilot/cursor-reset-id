# set color theme
$Theme = @{
    Primary   = 'Cyan'
    Success   = 'Green'
    Warning   = 'Yellow'
    Error     = 'Red'
    Info      = 'White'
}

# ASCII Logo
$Logo = @"
"@

# Beautiful Output Function
function Write-Styled {
    param (
        [string]$Message,
        [string]$Color = $Theme.Info,
        [string]$Prefix = "",
        [switch]$NoNewline
    )
    $symbol = switch ($Color) {
        $Theme.Success { "[OK]" }
        $Theme.Error   { "[X]" }
        $Theme.Warning { "[!]" }
        default        { "[*]" }
    }
    
    $output = if ($Prefix) { "$symbol $Prefix :: $Message" } else { "$symbol $Message" }
    if ($NoNewline) {
        Write-Host $output -ForegroundColor $Color -NoNewline
    } else {
        Write-Host $output -ForegroundColor $Color
    }
}

# Get version number function
function Get-LatestVersion {
    try {
        $latestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/yeongpin/cursor-free-vip/releases/latest"
        return @{
            Version = $latestRelease.tag_name.TrimStart('v')
            Assets = $latestRelease.assets
        }
    } catch {
        Write-Styled $_.Exception.Message -Color $Theme.Error -Prefix "Error"
        throw "Cannot get latest version"
    }
}

# Show Logo
Write-Host $Logo -ForegroundColor $Theme.Primary
$releaseInfo = Get-LatestVersion
$version = $releaseInfo.Version


# Set TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Function to start program as current user (even if PowerShell is running as admin)
function Start-ProgramAsCurrentUser {
    param (
        [string]$FilePath
    )
    try {
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        if ($isAdmin) {
            # If running as admin, use explorer.exe to run as current user
            # explorer.exe always runs with current user privileges
            Write-Styled "PowerShell is running as admin, starting program as current user via explorer..." -Color $Theme.Info -Prefix "Launch"
            $process = Start-Process -FilePath "explorer.exe" -ArgumentList "`"$FilePath`"" -PassThru -ErrorAction Stop
            
            if ($process) {
                Write-Styled "Program started as current user" -Color $Theme.Success -Prefix "Launch"
                return $true
            }
        } else {
            # If not running as admin, just start normally
            $startInfo = New-Object System.Diagnostics.ProcessStartInfo
            $startInfo.FileName = $FilePath
            $startInfo.UseShellExecute = $true
            $startInfo.WorkingDirectory = Split-Path $FilePath -Parent
            $process = [System.Diagnostics.Process]::Start($startInfo)
            
            if ($process) {
                Write-Styled "Program started successfully" -Color $Theme.Success -Prefix "Launch"
                return $true
            }
        }
        
        return $false
    } catch {
        Write-Styled "Error starting program: $($_.Exception.Message)" -Color $Theme.Warning -Prefix "Warning"
        return $false
    }
}

# Function to ensure config directory exists with proper permissions
function Ensure-ConfigDirectory {
    try {
        $documentsPath = [Environment]::GetFolderPath("MyDocuments")
        if (-not $documentsPath -or -not (Test-Path $documentsPath)) {
            Write-Styled "Documents folder not found, using user profile" -Color $Theme.Warning -Prefix "Warning"
            $documentsPath = [Environment]::GetFolderPath("UserProfile")
        }
        
        $configDir = Join-Path $documentsPath ".cursor-free-vip"
        $configFile = Join-Path $configDir "config.ini"
        
        # Create directory if it doesn't exist
        if (-not (Test-Path $configDir)) {
            Write-Styled "Creating config directory..." -Color $Theme.Primary -Prefix "Config"
            try {
                New-Item -ItemType Directory -Path $configDir -Force | Out-Null
                Write-Styled "Config directory created: $configDir" -Color $Theme.Success -Prefix "Config"
            } catch {
                Write-Styled "Failed to create config directory: $($_.Exception.Message)" -Color $Theme.Error -Prefix "Error"
                return $false
            }
        } else {
            Write-Styled "Config directory already exists: $configDir" -Color $Theme.Info -Prefix "Config"
        }
        
        # Fix permissions on directory
        try {
            $acl = Get-Acl $configDir
            $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
            $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($currentUser, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
            $acl.SetAccessRule($accessRule)
            Set-Acl $configDir $acl
            Write-Styled "Directory permissions set" -Color $Theme.Success -Prefix "Config"
        } catch {
            Write-Styled "Warning: Could not set directory permissions: $($_.Exception.Message)" -Color $Theme.Warning -Prefix "Warning"
        }
        
        # If config file exists, fix its permissions
        if (Test-Path $configFile) {
            Write-Styled "Config file exists, checking permissions..." -Color $Theme.Info -Prefix "Config"
            try {
                $acl = Get-Acl $configFile
                $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
                $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($currentUser, "FullControl", "Allow")
                $acl.SetAccessRule($accessRule)
                Set-Acl $configFile $acl
                Write-Styled "Config file permissions fixed" -Color $Theme.Success -Prefix "Config"
            } catch {
                Write-Styled "Warning: Could not fix config file permissions: $($_.Exception.Message)" -Color $Theme.Warning -Prefix "Warning"
                Write-Styled "Attempting to remove read-only attribute..." -Color $Theme.Warning -Prefix "Warning"
                try {
                    $file = Get-Item $configFile
                    $file.IsReadOnly = $false
                    $file.Attributes = $file.Attributes -band (-bnot [System.IO.FileAttributes]::ReadOnly)
                    Write-Styled "Read-only attribute removed" -Color $Theme.Success -Prefix "Config"
                } catch {
                    Write-Styled "Could not remove read-only attribute: $($_.Exception.Message)" -Color $Theme.Error -Prefix "Error"
                }
            }
        }
        
        # Test if directory is writable by attempting to create a test file
        try {
            $testFile = Join-Path $configDir ".write_test"
            $null = New-Item -ItemType File -Path $testFile -Force -ErrorAction Stop
            Remove-Item $testFile -Force -ErrorAction SilentlyContinue
            Write-Styled "Config directory is writable" -Color $Theme.Success -Prefix "Config"
        } catch {
            Write-Styled "Warning: Config directory may not be writable: $($_.Exception.Message)" -Color $Theme.Warning -Prefix "Warning"
            Write-Styled "Trying to fix permissions..." -Color $Theme.Warning -Prefix "Warning"
            
            # Try to take ownership and fix permissions
            try {
                $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
                $takeown = Start-Process -FilePath "takeown.exe" -ArgumentList "/F", "`"$configDir`"", "/R", "/D", "Y" -Wait -NoNewWindow -PassThru
                $icacls = Start-Process -FilePath "icacls.exe" -ArgumentList "`"$configDir`"", "/grant", "${currentUser}:F", "/T" -Wait -NoNewWindow -PassThru
                Write-Styled "Permissions fixed using takeown/icacls" -Color $Theme.Success -Prefix "Config"
            } catch {
                Write-Styled "Could not fix permissions automatically" -Color $Theme.Error -Prefix "Error"
                return $false
            }
        }
        
        return $true
    } catch {
        Write-Styled "Error ensuring config directory: $($_.Exception.Message)" -Color $Theme.Error -Prefix "Error"
        return $false
    }
}

# Main installation function
function Install-CursorFreeVIP {
    Write-Styled "Start downloading Cursor Free VIP" -Color $Theme.Primary -Prefix "Download"
    
    try {
        # Get latest version
        Write-Styled "Checking latest version..." -Color $Theme.Primary -Prefix "Update"
        $releaseInfo = Get-LatestVersion
        $version = $releaseInfo.Version
        Write-Styled "Found latest version: $version" -Color $Theme.Success -Prefix "Version"
        
        # Find corresponding resources
        $asset = $releaseInfo.Assets | Where-Object { $_.name -eq "CursorFreeVIP_${version}_windows.exe" }
        if (!$asset) {
            Write-Styled "File not found: CursorFreeVIP_${version}_windows.exe" -Color $Theme.Error -Prefix "Error"
            Write-Styled "Available files:" -Color $Theme.Warning -Prefix "Info"
            $releaseInfo.Assets | ForEach-Object {
                Write-Styled "- $($_.name)" -Color $Theme.Info
            }
            throw "Cannot find target file"
        }
        
        # Check if Downloads folder already exists for the corresponding version
        $DownloadsPath = [Environment]::GetFolderPath("UserProfile") + "\Downloads"
        $downloadPath = Join-Path $DownloadsPath "CursorFreeVIP_${version}_windows.exe"
        
        if (Test-Path $downloadPath) {
            Write-Styled "Found existing installation file" -Color $Theme.Success -Prefix "Found"
            Write-Styled "Location: $downloadPath" -Color $Theme.Info -Prefix "Location"
            
            # Ensure config directory exists before starting
            Write-Styled "Preparing config directory..." -Color $Theme.Primary -Prefix "Config"
            if (-not (Ensure-ConfigDirectory)) {
                Write-Styled "Warning: Config directory setup had issues, but continuing..." -Color $Theme.Warning -Prefix "Warning"
            }
            
            # Check if running with administrator privileges
            $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
            
            # Start program as current user (not admin)
            Write-Styled "Starting program..." -Color $Theme.Primary -Prefix "Launch"
            if (-not (Start-ProgramAsCurrentUser -FilePath $downloadPath)) {
                Write-Styled "Failed to start program, trying direct method..." -Color $Theme.Warning -Prefix "Warning"
                Start-Process -FilePath $downloadPath -WorkingDirectory (Split-Path $downloadPath -Parent)
            }
            return
        }
        
        Write-Styled "No existing installation file found, starting download..." -Color $Theme.Primary -Prefix "Download"

        # Use HttpWebRequest for chunked download with real-time progress bar
        $url = $asset.browser_download_url
        $outputFile = $downloadPath
        Write-Styled "Downloading from: $url" -Color $Theme.Info -Prefix "URL"
        Write-Styled "Saving to: $outputFile" -Color $Theme.Info -Prefix "Path"

        $request = [System.Net.HttpWebRequest]::Create($url)
        $request.UserAgent = "PowerShell Script"
        $response = $request.GetResponse()
        $totalLength = $response.ContentLength
        $responseStream = $response.GetResponseStream()
        $fileStream = [System.IO.File]::OpenWrite($outputFile)
        $buffer = New-Object byte[] 8192
        $bytesRead = 0
        $totalRead = 0
        $lastProgress = -1
        $startTime = Get-Date
        try {
            do {
                $bytesRead = $responseStream.Read($buffer, 0, $buffer.Length)
                if ($bytesRead -gt 0) {
                    $fileStream.Write($buffer, 0, $bytesRead)
                    $totalRead += $bytesRead
                    $progress = [math]::Round(($totalRead / $totalLength) * 100, 1)
                    if ($progress -ne $lastProgress) {
                        $elapsed = (Get-Date) - $startTime
                        $speed = if ($elapsed.TotalSeconds -gt 0) { $totalRead / $elapsed.TotalSeconds } else { 0 }
                        $speedDisplay = if ($speed -gt 1MB) {
                            "{0:N2} MB/s" -f ($speed / 1MB)
                        } elseif ($speed -gt 1KB) {
                            "{0:N2} KB/s" -f ($speed / 1KB)
                        } else {
                            "{0:N2} B/s" -f $speed
                        }
                        $downloadedMB = [math]::Round($totalRead / 1MB, 2)
                        $totalMB = [math]::Round($totalLength / 1MB, 2)
                        Write-Progress -Activity "Downloading CursorFreeVIP" -Status "$downloadedMB MB / $totalMB MB ($progress%) - $speedDisplay" -PercentComplete $progress
                        $lastProgress = $progress
                    }
                }
            } while ($bytesRead -gt 0)
        } finally {
            $fileStream.Close()
            $responseStream.Close()
            $response.Close()
        }
        Write-Progress -Activity "Downloading CursorFreeVIP" -Completed
        # Check file exists and is not zero size
        if (!(Test-Path $outputFile) -or ((Get-Item $outputFile).Length -eq 0)) {
            throw "Download failed or file is empty."
        }
        Write-Styled "Download completed!" -Color $Theme.Success -Prefix "Complete"
        Write-Styled "File location: $outputFile" -Color $Theme.Info -Prefix "Location"
        
        # Ensure config directory exists before starting
        Write-Styled "Preparing config directory..." -Color $Theme.Primary -Prefix "Config"
        if (-not (Ensure-ConfigDirectory)) {
            Write-Styled "Warning: Config directory setup had issues, but continuing..." -Color $Theme.Warning -Prefix "Warning"
        }
        
        Write-Styled "Starting program..." -Color $Theme.Primary -Prefix "Launch"
        if (-not (Start-ProgramAsCurrentUser -FilePath $outputFile)) {
            Write-Styled "Failed to start program, trying direct method..." -Color $Theme.Warning -Prefix "Warning"
            Start-Process -FilePath $outputFile -WorkingDirectory (Split-Path $outputFile -Parent)
        }
    }
    catch {
        Write-Styled $_.Exception.Message -Color $Theme.Error -Prefix "Error"
        throw
    }
}

# Execute installation
try {
    Install-CursorFreeVIP
}
catch {
    Write-Styled "Download failed" -Color $Theme.Error -Prefix "Error"
    Write-Styled $_.Exception.Message -Color $Theme.Error
}
finally {
    Write-Host "`nPress any key to exit..." -ForegroundColor $Theme.Info
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}
