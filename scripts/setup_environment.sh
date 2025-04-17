#!/bin/bash

# Configure Git to rewrite URLs for the specific repository
git config --global url."git@github.com:MarlovOne/flir-sdk".insteadOf "https://github.com/MarlovOne/flir-sdk"
git config --global url."git@github.com:MarlovOne/sla-sdk".insteadOf "https://github.com/MarlovOne/sla-sdk"