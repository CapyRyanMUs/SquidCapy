param(
    [string]$Godot = 'C:/Users/CapyRyan/Documents/Godot/Godots/Godot_v4.7.2-stable_win64.exe',
    [int]$Clients = 1,
    [int]$Npcs = 40,
    [int]$Port = 17000
)
$ErrorActionPreference = 'Stop'
$projectDir = Split-Path -Parent $PSScriptRoot
$logDir = Join-Path $projectDir '.godot/network-tests'
New-Item -ItemType Directory -Force $logDir | Out-Null
$processes = @()
function Launch-Game([string]$Name, [string[]]$GameArgs) {
    $log = Join-Path $logDir ($Name + '.log')
    if (Test-Path -LiteralPath $log) { Remove-Item -LiteralPath $log }
    $arguments = @('--headless', '--path', ('"' + $projectDir + '"'), '--max-fps', '60',
        '--quit-after', '2400', '--log-file', ('"' + $log + '"'), '--') + $GameArgs
    return Start-Process -FilePath $Godot -ArgumentList $arguments -WindowStyle Hidden -PassThru
}
try {
    $readyPath = Join-Path $projectDir ".godot/test_${Port}_listening.ready"
    if (Test-Path -LiteralPath $readyPath) { Remove-Item -LiteralPath $readyPath }
    $processes += Launch-Game 'host' @('--host', '--auto-ready', '--start-after=8', '--test-duration=8',
        "--npcs=$Npcs", "--port=$Port", '--quit-after=60', '--quit-on-result', '--name=Host', '--report',
        ("--expect-humans=" + ($Clients + 1)))
    $readyDeadline = [DateTime]::UtcNow.AddSeconds(30)
    $hostLogPath = Join-Path $logDir 'host.log'
    do {
        Start-Sleep -Milliseconds 100
        $ready = Test-Path -LiteralPath $readyPath
    } while (!$ready -and [DateTime]::UtcNow -lt $readyDeadline)
    if (!$ready) { throw 'Host did not finish initializing.' }
    for ($i = 1; $i -le $Clients; $i++) {
        $processes += Launch-Game "client$i" @('--join=127.0.0.1', '--auto-ready',
            "--port=$Port", '--quit-after=60', '--quit-on-result', "--name=Client$i", '--report')
        Start-Sleep -Milliseconds 150
    }
    foreach ($process in $processes) {
        if (!$process.WaitForExit(60000)) { throw "Test process timed out: $($process.Id)" }
    }
    $hostLog = Get-Content -LiteralPath (Join-Path $logDir 'host.log') -Raw
    if ($hostLog -notmatch ("MATCH_STARTED humans=" + ($Clients + 1) + " npcs=$Npcs")) {
        throw 'Host did not start with the expected participants.'
    }
    if ($hostLog -notmatch 'MATCH_RESULT (.+)') { throw 'Host did not finish the round.' }
    $expected = $Matches[1].Trim()
    foreach ($name in @('host') + @(1..$Clients | ForEach-Object { "client$_" })) {
        $content = Get-Content -LiteralPath (Join-Path $logDir ($name + '.log')) -Raw
        if ($content -match 'SCRIPT ERROR|Parse Error|Condition .* is true|RPC.*failed|unknown peer ID|Unable to send packet') {
            throw "Engine/script error in $name. Inspect $logDir"
        }
        if ($content -notmatch 'MATCH_RESULT (.+)' -or $Matches[1].Trim() -ne $expected) {
            throw "Results differ for $name."
        }
    }
    Write-Output "PASS: $($Clients + 1) humans, $Npcs NPCs; identical results in every process."
    Write-Output "Logs: $logDir"
} finally {
    foreach ($process in $processes) {
        if (!$process.HasExited) { Stop-Process -Id $process.Id }
    }
}
