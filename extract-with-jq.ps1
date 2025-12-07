# Extract metrics analysis using jq for a single project
# Usage: .\extract-with-jq.ps1 -ProjectName "P1-googleapis"

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectName
)

$ResultsPath = "results\$ProjectName"
$ErrorsFile = "$ResultsPath\errors.json"
$ResultsFile = "$ResultsPath\results.json"
$OutputFile = "$ResultsPath\analysis-jq.json"

if (-not (Test-Path $ErrorsFile)) {
    Write-Error "Errors file not found: $ErrorsFile"
    exit 1
}

if (-not (Test-Path $ResultsFile)) {
    Write-Error "Results file not found: $ResultsFile"
    exit 1
}

Write-Host "Processing project: $ProjectName using jq"

# Check if jq is available
$jqAvailable = Get-Command jq -ErrorAction SilentlyContinue

if (-not $jqAvailable) {
    Write-Error "jq is not installed. Please install jq: https://stedolan.github.io/jq/download/"
    Write-Host "Windows: scoop install jq OR choco install jq"
    exit 1
}

# Merge errors.json and results.json for processing
$errorsContent = Get-Content $ErrorsFile -Raw | ConvertFrom-Json -AsHashtable
$resultsContent = Get-Content $ResultsFile -Raw | ConvertFrom-Json -AsHashtable

# Create combined object
$combined = [PSCustomObject]@{
    projectId = $resultsContent.projectId
    projectName = $resultsContent.projectName
    analyzedAt = $resultsContent.analyzedAt
    totalFiles = $resultsContent.totalFiles
    metricsAvailable = $resultsContent.metricsAvailable
    file = $errorsContent.file
    parse = $errorsContent.parse
    metric = $errorsContent.metric
    traverse = $errorsContent.traverse
}

# Save combined to temp file
$tempFile = "$ResultsPath\temp-combined.json"
$combined | ConvertTo-Json -Depth 10 | Out-File $tempFile -Encoding UTF8

# Run jq script
Write-Host "Running jq extraction..."
jq -f extract-errors.jq $tempFile | Out-File $OutputFile -Encoding UTF8

# Clean up temp file
Remove-Item $tempFile

Write-Host "Analysis complete. Output saved to: $OutputFile"

# Display summary
$analysis = Get-Content $OutputFile -Raw | ConvertFrom-Json -AsHashtable
Write-Host "\nProject: $($analysis.project.projectName)"
Write-Host "Total Errors: $($analysis.errors.summary.total)"
Write-Host "  - File errors: $($analysis.errors.summary.totalFileErrors)"
Write-Host "  - Parse errors: $($analysis.errors.summary.totalParseErrors)"
Write-Host "  - Metric errors: $($analysis.errors.summary.totalMetricErrors)"
Write-Host "  - Traverse errors: $($analysis.errors.summary.totalTraverseErrors)"
