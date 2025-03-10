#! /usr/bin/env pwsh
# Get opencv into the environment if it's installed: $env:OpenCV_DIR='C:\tools\opencv\build'
# Run command: powershell -ExecutionPolicy Bypass -File .\make_windows.ps1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("x86_64", "aarch64", "x64", "x64_arm64", "arm64")]
    [string]$arch,

    [Parameter(Mandatory = $false)]
    [string]$buildType = "Release",

    [Parameter(Mandatory = $false)]
    [ValidateSet("ON", "OFF")]
    [string]$maintainerMode = "ON",

    [Parameter(Mandatory = $false)]
    [string]$gitSha = "",

    [Parameter(Mandatory = $false)]
    [ValidateSet("TRUE", "FALSE")]
    [string]$enableCoverage = "FALSE",

    [Parameter(Mandatory = $false)]
    [string]$buildDir = ""  # Optional base build directory
)

$env:CPM_SOURCE_CACHE = "C:\git\cpm\cache"

# Define architectures: if an architecture was provided, use it; otherwise, use both.
if ($arch) {
    if ($arch -eq "aarch64" -or $arch -eq "arm64") {
        $ARCHS = @("x64_arm64")
    }
    elseif ($arch -eq "x86_64") {
        $ARCHS = @("x64")
    }
    else {
        $ARCHS = @($arch)
    }
}
else {
    $ARCHS = @("x64", "x64_arm64")
}

# Get the directory containing this script
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Navigate to the parent directory of the scripts folder
Push-Location (Join-Path $SCRIPT_DIR "..")

foreach ($ARCH in $ARCHS) {

    # Use provided buildDir if available; otherwise, use default
    if ($buildDir -eq "") {
        $BuildDir = "$PWD\build\Windows\backend\$ARCH"
    }
    
    $InstallDir = "$PWD\install\Windows\backend\$ARCH"
    $targetPath = "blabla\windows\arch\$ARCH"

    # Remove previous build and artifacts
    Remove-Item -Recurse -Force $BuildDir -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force $InstallDir -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force $targetPath -ErrorAction SilentlyContinue

    ## Store the output of cmd.exe. We also ask cmd.exe to output the environment table after the batch file completes
    $tempFile = [IO.Path]::GetTempFileName()
    cmd /c " `"C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat`" $ARCH && set > `"$tempFile`" "

    ## Set environment variables from the temporary file
    Get-Content $tempFile | ForEach-Object {
        if ($_ -match "^(.*?)=(.*)$") {
            Set-Item -Path "env:$($matches[1])" -Value $matches[2]
        }
    }
    Remove-Item $tempFile

    if ($ARCH -eq "x64_arm64") {
        cmake -S test_repo -B $BuildDir `
            -Dtest_repo_PACKAGING_MAINTAINER_MODE="$maintainerMode" `
            -G "Visual Studio 17 2022" `
            -T ClangCL `
            -A ARM64 `
            -DBUILD_TESTING=OFF `
            -DCMAKE_SYSTEM_PROCESSOR=ARM64 `
            -DCMAKE_CONFIGURATION_TYPES="Release;Debug" `
            -DCMAKE_BUILD_TYPE="$buildType" `
            -DBUILD_SHARED_LIBS=ON `
            -DGIT_SHA="$gitSha" `
            -Dtest_repo_ENABLE_COVERAGE="$enableCoverage"
    }
    elseif ($ARCH -eq "x64") {
        cmake -S test_repo -B $BuildDir `
            -Dtest_repo_PACKAGING_MAINTAINER_MODE="$maintainerMode" `
            -G "Visual Studio 17 2022" `
            -T ClangCL `
            -DCMAKE_BUILD_TYPE="$buildType" `
            -DBUILD_SHARED_LIBS=ON `
            -DGIT_SHA="$gitSha" `
            -Dtest_repo_ENABLE_COVERAGE="$enableCoverage"
    }
    else {
        Write-Host "Unsupported architecture: $ARCH"
        exit 1
    }

    # Build the project
    cmake --build $BuildDir --config $buildType --verbose

    # Install the project
    New-Item -ItemType Directory -Path "artifacts\windows\$ARCH" -Force | Out-Null
    cmake --install $BuildDir --prefix (Resolve-Path "artifacts\windows\$ARCH")

    # Ensure the target directory exists
    if (!(Test-Path $targetPath -PathType Container)) {
        Remove-Item -Force $targetPath -ErrorAction SilentlyContinue  # Remove if it's a conflicting file
        New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
    }

    # Copy artifacts safely
    Copy-Item -Recurse -Force "artifacts\windows\$ARCH\*" $targetPath
}

# Return to the previous directory
Pop-Location
