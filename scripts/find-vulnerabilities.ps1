$repoRoot = Split-Path -Parent $PSScriptRoot
$reportDirectory = Join-Path $repoRoot 'security/trivy'

$filter = @'
.Results[]?.Vulnerabilities[]?
| select(.Severity == $high or .Severity == $critical)
| [
    .Severity,
    .VulnerabilityID,
    .PkgName,
    .InstalledVersion,
    .FixedVersion
  ]
| @tsv
'@

Get-ChildItem (Join-Path $reportDirectory 'trivy-report-*.json') | ForEach-Object {
    Write-Host "`n========== $($_.Name) =========="
    & jq.exe -r --arg high HIGH --arg critical CRITICAL $filter $_.FullName
}