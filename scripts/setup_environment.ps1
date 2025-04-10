#! /usr/bin/env pwsh

# Directly set Git to rewrite the URL for the specific repository
git config --global url."git@github.com:MarlovOne/flir-sdk".insteadOf "https://github.com/MarlovOne/flir-sdk"
git config --global url."git@github.com:MarlovOne/sla-sdk".insteadOf "https://github.com/MarlovOne/sla-sdk"

Write-Output "Git URL rewriting has been configured successfully."
