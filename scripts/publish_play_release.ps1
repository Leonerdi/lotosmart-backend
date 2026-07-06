param(
    [ValidateSet('internal', 'alpha', 'beta', 'production')]
    [string]$Track = 'internal',

    [ValidateSet('draft', 'completed', 'halted', 'inProgress')]
    [string]$ReleaseStatus = 'completed',

    [string]$ServiceAccountJson = '',

    [string]$AabPath = 'lotofacil_app/build/app/outputs/bundle/release/app-release.aab',

    [string]$ReleaseName,

    [string]$ReleaseNotesFile,

    [switch]$ChangesNotSentForReview
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$pythonExe = Join-Path $repoRoot '.venv\Scripts\python.exe'
$pubspecPath = Join-Path $repoRoot 'lotofacil_app\pubspec.yaml'

if (-not $ServiceAccountJson) {
    $candidateServiceAccounts = @(
        'play-console/lotosmart-play-publisher.json',
        'play-console/ga4-automation-sa.json'
    )

    foreach ($candidate in $candidateServiceAccounts) {
        if (Test-Path (Join-Path $repoRoot $candidate)) {
            $ServiceAccountJson = $candidate
            break
        }
    }
}

if (-not $ServiceAccountJson) {
    throw 'Nao foi encontrado JSON de service account. Informe -ServiceAccountJson ou coloque o arquivo em play-console/.'
}

$serviceAccountPath = Join-Path $repoRoot $ServiceAccountJson
if (-not (Test-Path $serviceAccountPath)) {
    throw "JSON da service account nao encontrado: $serviceAccountPath"
}

if (-not (Test-Path $pythonExe)) {
    throw "Python do ambiente virtual nao encontrado em $pythonExe"
}

if (-not $ReleaseName) {
    $versionLine = Select-String -Path $pubspecPath -Pattern '^version:\s*(.+)$' | Select-Object -First 1
    if ($null -eq $versionLine) {
        throw 'Nao foi possivel detectar a versao em lotofacil_app/pubspec.yaml'
    }
    $ReleaseName = $versionLine.Matches[0].Groups[1].Value.Trim()
}

if (-not $ReleaseNotesFile) {
    $candidateNotes = Join-Path $repoRoot "play\release-notes\pt-BR\$ReleaseName.txt"
    if (Test-Path $candidateNotes) {
        $ReleaseNotesFile = $candidateNotes
    }
}

$commandArgs = @(
    (Join-Path $repoRoot 'scripts\publish_play_release.py')
    '--service-account-json', $serviceAccountPath
    '--aab', (Join-Path $repoRoot $AabPath)
    '--track', $Track
    '--release-status', $ReleaseStatus
    '--release-name', $ReleaseName
)

if ($ReleaseNotesFile) {
    $commandArgs += @('--release-notes-file', $ReleaseNotesFile)
}

if ($ChangesNotSentForReview) {
    $commandArgs += '--changes-not-sent-for-review'
}

& $pythonExe @commandArgs