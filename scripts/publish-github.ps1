# Publish Musix to GitHub, then trigger the IPA release workflow.
# Requirements: git + GitHub CLI (https://cli.github.com) logged in.
# Usage (from the repo root):  powershell -ExecutionPolicy Bypass -File .\scripts\publish-github.ps1 -RepoName musix

param(
    [string]$RepoName = "musix",
    [string]$Tag = "v1.0.0",
    [switch]$Private,
    [switch]$Release
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw "git is not installed." }
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { throw "GitHub CLI (gh) is not installed. See https://cli.github.com" }

gh auth status *> $null
if ($LASTEXITCODE -ne 0) { gh auth login }

if (-not (Test-Path ".git")) {
    git init -b main
}

git add .
git commit -m "Musix: invite-only music app for iOS" 2>$null

$remotes = git remote
if (-not $remotes) {
    gh repo create $RepoName --source=. --remote=origin --push --description "Musix — music, minus the noise."
} else {
    git push -u origin main
}

git push origin main

if ($Release) {
    if (-not (git tag -l $Tag)) { git tag $Tag }
    git push origin $Tag
    Write-Host "Pushed tag $Tag — the iOS workflow will attach Musix.ipa to the GitHub Release."
} else {
    Write-Host "Pushed. Trigger 'Build & release IPA' in the Actions tab and tick 'Publish the IPA to GitHub Releases'."
}

Write-Host "Repo: $(gh repo view --json url --jq .url)"
