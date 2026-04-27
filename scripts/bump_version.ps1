param(
    [ValidateSet("patch", "minor", "major")]
    [string]$Part = "patch",
    [string]$PubspecPath = "flutter_app/pubspec.yaml"
)

if (-not (Test-Path -LiteralPath $PubspecPath)) {
    throw "pubspec not found: $PubspecPath"
}

$raw = Get-Content -LiteralPath $PubspecPath -Raw
$match = [regex]::Match($raw, '(?m)^version:\s*(\d+)\.(\d+)\.(\d+)(?:\+\d+)?\s*$')
if (-not $match.Success) {
    throw "version field not found in $PubspecPath"
}

$major = [int]$match.Groups[1].Value
$minor = [int]$match.Groups[2].Value
$patch = [int]$match.Groups[3].Value
switch ($Part) {
    "major" {
        $major += 1
        $minor = 0
        $patch = 0
    }
    "minor" {
        $minor += 1
        $patch = 0
    }
    default {
        $patch += 1
    }
}

$next = "$major.$minor.$patch"
$updated = [regex]::Replace($raw, '(?m)^version:\s*.*$', "version: $next", 1)
Set-Content -LiteralPath $PubspecPath -Value $updated -Encoding utf8

Write-Output "Version bumped: $($match.Groups[0].Value.Trim()) -> version: $next"
