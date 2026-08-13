param([switch]$DryRun)

$ErrorActionPreference = 'Stop'

$src    = $PSScriptRoot
$target = Join-Path $env:USERPROFILE '.claude'

foreach ($kind in @('skills', 'agents')) {
    $from = Join-Path $src $kind
    if (-not (Test-Path $from)) { continue }

    $to = Join-Path $target $kind
    if (-not $DryRun -and -not (Test-Path $to)) {
        New-Item -ItemType Directory -Path $to -Force | Out-Null
    }

    foreach ($item in Get-ChildItem -Path $from) {
        $dest = Join-Path $to $item.Name
        $verb = if (Test-Path $dest) { 'обновлён' } else { 'добавлен' }

        if ($DryRun) {
            Write-Host "[dry-run] $kind/$($item.Name) -> $dest ($verb)"
            continue
        }

        if ($item.PSIsContainer -and (Test-Path $dest)) {
            Remove-Item -Path $dest -Recurse -Force
        }
        Copy-Item -Path $item.FullName -Destination $dest -Recurse -Force
        Write-Host "$kind/$($item.Name) — $verb"
    }
}

Write-Host ''
Write-Host "Цель: $target"
if ($DryRun) {
    Write-Host 'Ничего не скопировано (-DryRun).'
} else {
    Write-Host 'Готово. Изменения подхватятся в новой сессии Claude Code.'
}
