# Upload audio/artwork and publish tracks over the air (Windows / PowerShell).
#
#   $env:MUSIX_API = "https://musix-api.you.workers.dev"
#   $env:MUSIX_ADMIN_TOKEN = "…"
#   .\scripts\upload-music.ps1 -File song.mp3, cover.jpg
#   .\scripts\upload-music.ps1 -Tracks .\backend\examples\tracks.sample.json
#
# The audio must be yours to stream.

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string[]]$File,

    [string]$Api = $env:MUSIX_API,
    [string]$Token = $env:MUSIX_ADMIN_TOKEN,
    [switch]$Tracks
)

$ErrorActionPreference = "Stop"

if (-not $Api) { throw "Set MUSIX_API (or -Api) to your Worker URL." }
if (-not $Token) { throw "Set MUSIX_ADMIN_TOKEN (or -Token)." }

$Api = $Api.TrimEnd("/")
$headers = @{ "x-musix-admin" = $Token }

function Get-ContentType([string]$name) {
    switch -Regex ($name.ToLowerInvariant()) {
        "\.mp3$" { return "audio/mpeg" }
        "\.(m4a|aac)$" { return "audio/mp4" }
        "\.flac$" { return "audio/flac" }
        "\.wav$" { return "audio/wav" }
        "\.(mp4|m4v)$" { return "video/mp4" }
        "\.mov$" { return "video/quicktime" }
        "\.(jpg|jpeg)$" { return "image/jpeg" }
        "\.png$" { return "image/png" }
        "\.webp$" { return "image/webp" }
        default { return "application/octet-stream" }
    }
}

if ($Tracks) {
    $json = $File[0]
    if (-not (Test-Path $json)) { throw "No such file: $json" }

    $response = Invoke-RestMethod `
        -Uri "$Api/v1/admin/tracks" `
        -Method Post `
        -Headers $headers `
        -ContentType "application/json" `
        -InFile (Resolve-Path $json)

    $response | ConvertTo-Json -Depth 5
    exit 0
}

foreach ($path in $File) {
    if (-not (Test-Path $path)) { throw "No such file: $path" }

    $item = Get-Item $path
    $name = ($item.Name -replace '[^A-Za-z0-9._-]', '-')
    Write-Host "Uploading $name…"

    $response = Invoke-RestMethod `
        -Uri "$Api/v1/admin/media?name=$name" `
        -Method Post `
        -Headers $headers `
        -ContentType (Get-ContentType $item.Name) `
        -InFile $item.FullName

    Write-Host "  $($response.url)"
    $response | ConvertTo-Json -Depth 5
}
