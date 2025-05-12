<#
.SYNOPSIS
Sets up DigiCert KeyLocker KSP and smctl (if needed) and signs a specified file
or all matching files within a specified directory using smctl on Windows.

.DESCRIPTION
This script automates the process of signing Windows executables or libraries
using smctl and DigiCert KeyLocker. It includes steps to check for and
install KeyLocker Tools (which includes smctl and KSP components), register
the KSP, sync certificates, and then perform the signing operation on either
a single file or multiple files within a directory.

Requires Administrator privileges to install tools and register the KSP.
Signing itself can usually be done as a regular user once setup is complete.

.PARAMETER InputPath
The full path to the file or directory to process.
If a file path is provided, only that file will be signed.
If a directory path is provided, files within that directory matching the -Filter
will be signed. This parameter is mandatory.

.PARAMETER Filter
An array of file filters (wildcards) used when -InputPath is a directory.
Defaults to '*.exe', '*.dll'. Example: -Filter '*.exe', '*.dll', '*.sys'

.PARAMETER Recurse
Switch parameter. If specified when -InputPath is a directory, the script will
search for files matching the -Filter in subdirectories as well.

.PARAMETER ForceKSPSetup
Switch parameter. If specified, the script will attempt to download, install,
register the KSP, and sync certificates even if the tools directory exists.
Useful for ensuring a clean setup in CI/CD environments.

.EXAMPLE
# Sign a single file
.\Sign-WithSmctl.ps1 -InputPath "C:\path\to\your\application.exe"

.EXAMPLE
# Sign all .exe and .dll files in a specific directory (non-recursive)
.\Sign-WithSmctl.ps1 -InputPath "C:\path\to\build\output"

.EXAMPLE
# Sign all .exe files recursively in a directory
.\Sign-WithSmctl.ps1 -InputPath "C:\path\to\project" -Filter '*.exe' -Recurse

.EXAMPLE
# Force KSP/smctl setup steps before signing files in a directory
.\Sign-WithSmctl.ps1 -InputPath "C:\path\to\build\output" -ForceKSPSetup

.NOTES
Prerequisites:
1. PowerShell running with Administrator privileges is REQUIRED for the setup steps
   (installing MSI, registering KSP).
2. signtool.exe (from Windows SDK) must be installed and accessible via the system PATH.
3. The following environment variables must be set persistently for the user running the script:
   - SM_HOST
   - SM_API_KEY
   - SM_CLIENT_CERT_FILE (path to .p12 Authentication Certificate)
   - SM_CLIENT_CERT_PASSWORD (password for .p12 file)
   - SM_CODE_SIGNING_CERT_SHA1_HASH (Fingerprint of the code signing certificate)
4. The user associated with the API Key/Auth Cert must be an authorized signer for the
   specified code signing certificate within DigiCert ONE / KeyLocker.

The script attempts KSP/smctl setup only if the tools directory is missing or if -ForceKSPSetup is used.
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [string[]]$Filter = @("*.exe", "*.dll"), # Default filter

    [Switch]$Recurse,

    [Switch]$ForceKSPSetup
)

# --- Configuration ---
$keylockerToolsPath = "C:\Program Files\DigiCert\DigiCert Keylocker Tools" # Default install path
$smctlExePath = Join-Path $keylockerToolsPath "smctl.exe"
$smkspRegPath = Join-Path $keylockerToolsPath "smksp_registrar.exe"
$smkspSyncPath = Join-Path $keylockerToolsPath "smksp_cert_sync.exe"
$keylockerMsiUrlTemplate = "https://one.digicert.com/signingmanager/api-ui/v1/releases/Keylockertools-windows-x64.msi/download" # URL Template
$msiDownloadPath = Join-Path $env:TEMP "Keylockertools-windows-x64.msi"

# --- Function to check if running as Administrator ---
function Test-IsAdmin {
    try {
        $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [System.Security.Principal.WindowsPrincipal]::new($identity)
        return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        Write-Warning "Could not determine administrator status: $($_.Exception.Message)"
        return $false # Assume not admin if check fails
    }
}

# --- Function to Sign and Verify a single file ---
function Invoke-SignAndVerify {
    param(
        [string]$TargetFilePath,
        [string]$CertFingerprint
    )

    Write-Host "--> Attempting to sign file: $TargetFilePath"
    $signSuccess = $false
    try {
        # Execute smctl sign command
        $output = smctl sign --fingerprint $CertFingerprint --input $TargetFilePath --verbose
        Write-Host $output

        # Check the exit code of the last command
        if ($LASTEXITCODE -ne 0) {
            Write-Error "  smctl sign command failed for '$TargetFilePath'. See output above. Exit code: $LASTEXITCODE"
            # Optionally add specific error guidance here
        }
        else {
            Write-Host "  [SUCCESS] File successfully signed: $TargetFilePath"
            $signSuccess = $true
        }
    }
    catch {
        Write-Error "  An unexpected error occurred during signing '$TargetFilePath': $($_.Exception.Message)"
    }

    # Verification Step (only if signing appeared successful)
    if ($signSuccess) {
        Write-Host "  --> Attempting to verify signature for: $TargetFilePath"
        try {
            signtool verify /pa /v $TargetFilePath
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "  signtool verification reported an issue for '$TargetFilePath'. See output above. Exit code: $LASTEXITCODE"
            }
            else {
                Write-Host "  [OK] Signature verification successful for '$TargetFilePath'."
            }
        }
        catch {
            Write-Warning "  An error occurred during signtool verification for '$TargetFilePath': $($_.Exception.Message)"
        }
    }
    return $signSuccess # Return status for the file
}


# --- Script Start ---

$isAdmin = Test-IsAdmin
Write-Host "Starting signing process for input path: $InputPath"
Write-Host "Running as Administrator: $isAdmin"

# --- Prerequisite Checks ---

# 1. Check if the input path exists (as file or directory)
if (-not (Test-Path -Path $InputPath)) {
    Write-Error "Input path not found: $InputPath"
    exit 1
}
$isInputDirectory = Test-Path -Path $InputPath -PathType Container
Write-Host "[OK] Input path found. Is Directory: $isInputDirectory"

# 2. Check for signtool.exe in PATH
$signtoolExists = Get-Command signtool.exe -ErrorAction SilentlyContinue
if (-not $signtoolExists) {
    Write-Error "signtool.exe not found in PATH. Please install the Windows SDK and add the directory containing signtool.exe to your PATH."
    exit 1
}
Write-Host "[OK] signtool.exe found in PATH."

# 3. Check for required environment variables
$requiredVars = @("SM_HOST", "SM_API_KEY", "SM_CLIENT_CERT_FILE", "SM_CLIENT_CERT_PASSWORD", "SM_CODE_SIGNING_CERT_SHA1_HASH")
$missingVars = @()
foreach ($varName in $requiredVars) {
    if (-not (Test-Path Env:\$varName)) {
        $missingVars += $varName
    }
}
if ($missingVars.Count -gt 0) {
    Write-Error "Missing required environment variables: $($missingVars -join ', '). Please set them persistently and restart your terminal."
    exit 1
}
Write-Host "[OK] Required environment variables found."
$signingCertFingerprint = $env:SM_CODE_SIGNING_CERT_SHA1_HASH
$apiKey = $env:SM_API_KEY # Needed for MSI download


# --- KSP and smctl Setup Section ---

# Determine if setup needs to run
$needsSetup = $false
if (-not (Test-Path -Path $keylockerToolsPath -PathType Container)) {
    Write-Host "DigiCert KeyLocker Tools directory not found at '$keylockerToolsPath'."
    $needsSetup = $true
}
elseif ($ForceKSPSetup) {
    Write-Host "-ForceKSPSetup specified, attempting KeyLocker Tools setup steps."
    $needsSetup = $true
}
else {
    Write-Host "[OK] DigiCert KeyLocker Tools directory found. Skipping setup unless forced."
}

if ($needsSetup) {
    Write-Host "Attempting KeyLocker Tools Setup (including smctl and KSP)..."
    if (-not $isAdmin) {
        Write-Error "Administrator privileges are required to install KeyLocker Tools and register KSP. Please re-run this script as Administrator."
        exit 1
    }

    # Download MSI
    Write-Host "Downloading KeyLocker Tools MSI..."
    try {
        $headers = @{ "x-api-key" = $apiKey }
        Invoke-WebRequest -Uri $keylockerMsiUrlTemplate -Headers $headers -OutFile $msiDownloadPath -UseBasicParsing
        Write-Host "[OK] MSI downloaded to $msiDownloadPath"
    }
    catch {
        Write-Error "Failed to download KeyLocker Tools MSI: $($_.Exception.Message)"
        Write-Error "Check network connection and ensure SM_API_KEY environment variable is correct."
        exit 1
    }

    # Install MSI silently
    Write-Host "Installing KeyLocker Tools (requires Administrator)..."
    $msiArgs = @("/i", "`"$msiDownloadPath`"", "/quiet", "/qn", "/norestart")
    $installProcess = Start-Process msiexec.exe -ArgumentList $msiArgs -Wait -PassThru
    if ($installProcess.ExitCode -ne 0) {
        Write-Error "MSI installation failed with exit code: $($installProcess.ExitCode). Check MSI logs if available."
        Remove-Item -Path $msiDownloadPath -Force -ErrorAction SilentlyContinue
        exit 1
    }
    Write-Host "[OK] KeyLocker Tools installed."
    Write-Host "Waiting for installation to finalize..."
    Start-Sleep -Seconds 30

    # Verify installation by checking for key files
    if (-not (Test-Path -Path $smctlExePath -PathType Leaf)) { Write-Error "smctl.exe not found at '$smctlExePath' after installation."; exit 1 }
    if (-not (Test-Path -Path $smkspRegPath -PathType Leaf)) { Write-Error "smksp_registrar.exe not found at '$smkspRegPath' after installation."; exit 1 }
    if (-not (Test-Path -Path $smkspSyncPath -PathType Leaf)) { Write-Error "smksp_cert_sync.exe not found at '$smkspSyncPath' after installation."; exit 1 }
    Write-Host "[OK] KeyLocker Tools executables verified."

    # Register KSP and Sync Certs (Requires Admin)
    Write-Host "Configuring KeyLocker KSP (requires Administrator)..."
    try {
        Push-Location $keylockerToolsPath
        Write-Host "  Resetting KSP registration..."
        .\smksp_registrar.exe remove; Start-Sleep -Seconds 5
        .\smksp_registrar.exe register; Start-Sleep -Seconds 5
        Write-Host "[OK] KSP registration attempted."
        Write-Host "  Syncing certificates..."
        .\smksp_cert_sync.exe
        Write-Host "[OK] Certificate sync attempted."
        Write-Host "  Listing registered KSPs..."; .\smksp_registrar.exe list
        Pop-Location
        Write-Host "[OK] KSP Setup complete."
    }
    catch {
        Pop-Location
        Write-Error "An error occurred during KSP setup: $($_.Exception.Message)"
        exit 1
    }
    Remove-Item -Path $msiDownloadPath -Force -ErrorAction SilentlyContinue
} # End of $needsSetup block

# --- Ensure smctl is callable ---
$pathArray = $env:PATH -split ';'
if (-not ($pathArray -contains $keylockerToolsPath)) {
    Write-Warning "KeyLocker Tools path '$keylockerToolsPath' not found in current session PATH."
    Write-Host "Adding '$keylockerToolsPath' to PATH for this session..."
    $env:PATH = "$keylockerToolsPath;$env:PATH"
}
$smctlExists = Get-Command smctl.exe -ErrorAction SilentlyContinue
if (-not $smctlExists) {
    Write-Error "smctl.exe is still not found or callable after setup attempt. Check installation and PATH configuration."
    exit 1
}
Write-Host "[OK] smctl.exe is available."

# --- Signing Process ---

$filesToSign = @()
if ($isInputDirectory) {
    Write-Host "Input is a directory. Searching for files matching filter: $($Filter -join ', ')"
    $filesToSign = @()
    foreach ($pattern in $Filter) {
        $searchParams = @{
            Path    = $InputPath
            Filter  = $pattern
            Recurse = $Recurse.IsPresent
            File    = $true
        }
        $found = Get-ChildItem @searchParams
        $filesToSign += $found
    }
    # Remove duplicates (in case patterns overlap)
    $filesToSign = $filesToSign | Sort-Object -Property FullName -Unique
}
else {
    # Input is a single file, check if it matches the filter (optional, but consistent)
    $fileInfo = Get-Item -Path $InputPath
    $matchesFilter = $false
    foreach ($f in $Filter) {
        if ($fileInfo.Name -like $f) {
            $matchesFilter = $true
            break
        }
    }
    if ($matchesFilter) {
        $filesToSign += $fileInfo
    }
    else {
        Write-Warning "Input file '$($fileInfo.Name)' does not match the specified filter ($($Filter -join ', ')). Skipping signing."
    }
}

if ($filesToSign.Count -eq 0) {
    Write-Warning "No files found matching the criteria to sign."
    exit 0 # Exit gracefully if no files need signing
}

Write-Host "Found $($filesToSign.Count) file(s) to sign."
$overallSuccess = $true

foreach ($file in $filesToSign) {
    $filePath = $file.FullName
    Write-Host "--------------------------------------------------"
    $fileSuccess = Invoke-SignAndVerify -TargetFilePath $filePath -CertFingerprint $signingCertFingerprint
    if (-not $fileSuccess) {
        $overallSuccess = $false
        # Decide if you want to stop on the first error
        # Write-Error "Stopping script due to signing failure on $filePath"; exit 1
    }
    Write-Host "--------------------------------------------------"
    Start-Sleep -Seconds 1 # Small delay between files
}


# --- Final Status ---
Write-Host "Signing script finished."
if (-not $overallSuccess) {
    Write-Error "One or more files failed to sign. Please review the logs above."
    # Exit with a non-zero code to indicate failure in automation pipelines
    exit 1
}
else {
    Write-Host "All targeted files signed and verified successfully."
    exit 0
}
