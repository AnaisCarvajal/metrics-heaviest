# Extract all projects using jq and export to Excel
# Usage: .\extract-all-with-jq.ps1

$ResultsDir = "results"
$OutputDir = "analysis-output"
$OutputExcel = "$OutputDir\metrics-analysis-jq.xlsx"

# Create output directory
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

Write-Host "Starting jq-based analysis of all projects..."

# Check if jq is available
$jqAvailable = Get-Command jq -ErrorAction SilentlyContinue
if (-not $jqAvailable) {
    Write-Error "jq is not installed. Please install jq: https://stedolan.github.io/jq/download/"
    Write-Host "Windows: scoop install jq OR choco install jq"
    exit 1
}

# Get all project directories
$projects = Get-ChildItem -Path $ResultsDir -Directory

$allProjectsData = @()

foreach ($project in $projects) {
    $projectName = $project.Name
    Write-Host "Processing: $projectName"
    
    try {
        # Run jq extraction for single project
        & .\extract-with-jq.ps1 -ProjectName $projectName
        
        # Load the generated analysis
        $analysisPath = "$ResultsDir\$projectName\analysis-jq.json"
        if (Test-Path $analysisPath) {
            $analysis = Get-Content $analysisPath -Raw | ConvertFrom-Json -AsHashtable
            $allProjectsData += $analysis
        }
    }
    catch {
        Write-Warning "Error processing ${projectName}: $($_.Exception.Message)"
    }
}

# Save consolidated JSON
$consolidatedJson = "$OutputDir\all-projects-jq-analysis.json"
$allProjectsData | ConvertTo-Json -Depth 10 | Out-File $consolidatedJson -Encoding UTF8

Write-Host "`nGenerating Excel report..."

# Prepare summary data for Excel
$summaryData = @()
foreach ($project in $allProjectsData) {
    $row = [PSCustomObject]@{
        'Project ID' = $project.project.projectId
        'Project Name' = $project.project.projectName
        'Analyzed At' = $project.project.analyzedAt
        'Total Files' = $project.project.totalFiles
        'File Errors' = $project.errors.summary.totalFileErrors
        'Parse Errors' = $project.errors.summary.totalParseErrors
        'Metric Errors' = $project.errors.summary.totalMetricErrors
        'Traverse Errors' = $project.errors.summary.totalTraverseErrors
        'Total Errors' = $project.errors.summary.total
        'Error Rate (%)' = if ($project.project.totalFiles -gt 0) { 
            [math]::Round(($project.errors.summary.total / $project.project.totalFiles) * 100, 2) 
        } else { 0 }
        'Metrics Available' = ($project.project.metricsAvailable -join ', ')
    }
    $summaryData += $row
}

# Prepare detailed error data
$errorDetails = @()
foreach ($project in $allProjectsData) {
    foreach ($errorType in @('file', 'parse', 'metric', 'traverse')) {
        $errors = $project.errors.details.$errorType
        if ($errors -and $errors.Count -gt 0) {
            foreach ($error in $errors) {
                $errorDetails += [PSCustomObject]@{
                    'Project ID' = $project.project.projectId
                    'Project Name' = $project.project.projectName
                    'Error Type' = $errorType
                    'Error Pattern' = $error.pattern
                    'Occurrences' = $error.occurrences
                    'Example 1' = if ($error.examples.Count -gt 0) { $error.examples[0] } else { '' }
                    'Example 2' = if ($error.examples.Count -gt 1) { $error.examples[1] } else { '' }
                    'Example 3' = if ($error.examples.Count -gt 2) { $error.examples[2] } else { '' }
                }
            }
        }
    }
}

# Export to Excel if module is available
if (Get-Module -ListAvailable -Name ImportExcel) {
    # Summary sheet
    $summaryData | Export-Excel -Path $OutputExcel -AutoSize -TableName "ProjectSummary" -WorksheetName "Summary" -FreezeTopRow -BoldTopRow
    
    # Error details sheet
    if ($errorDetails.Count -gt 0) {
        $errorDetails | Export-Excel -Path $OutputExcel -AutoSize -TableName "ErrorDetails" -WorksheetName "Error Details" -FreezeTopRow -BoldTopRow
    }
    
    # Error patterns aggregated across all projects
    $aggregatedErrors = $errorDetails | Group-Object -Property 'Error Pattern' | ForEach-Object {
        [PSCustomObject]@{
            'Error Pattern' = $_.Name
            'Total Occurrences' = ($_.Group | Measure-Object -Property Occurrences -Sum).Sum
            'Projects Affected' = ($_.Group | Select-Object -ExpandProperty 'Project Name' -Unique).Count
            'Error Type' = ($_.Group | Select-Object -ExpandProperty 'Error Type' -First 1)
            'Projects' = (($_.Group | Select-Object -ExpandProperty 'Project Name' -Unique) -join ', ')
        }
    } | Sort-Object -Property 'Total Occurrences' -Descending
    
    if ($aggregatedErrors.Count -gt 0) {
        $aggregatedErrors | Export-Excel -Path $OutputExcel -AutoSize -TableName "AggregatedErrors" -WorksheetName "Error Patterns" -FreezeTopRow -BoldTopRow
    }
    
    Write-Host "Excel report generated: $OutputExcel"
}
else {
    Write-Warning "ImportExcel module not found."
    Write-Host "Install with: Install-Module -Name ImportExcel -Scope CurrentUser"
    
    # Export to CSV as fallback
    $csvSummary = "$OutputDir\summary-jq.csv"
    $csvErrors = "$OutputDir\error-details-jq.csv"
    
    $summaryData | Export-Csv -Path $csvSummary -NoTypeInformation -Encoding UTF8
    
    if ($errorDetails.Count -gt 0) {
        $errorDetails | Export-Csv -Path $csvErrors -NoTypeInformation -Encoding UTF8
    }
    
    Write-Host "CSV files exported to: $OutputDir"
}

Write-Host "`n=== Analysis Complete ==="
Write-Host "Total projects analyzed: $($allProjectsData.Count)"
Write-Host "Consolidated JSON: $consolidatedJson"
Write-Host "Output directory: $OutputDir"

# Display summary statistics
$totalErrors = ($summaryData | Measure-Object -Property 'Total Errors' -Sum).Sum
$totalFiles = ($summaryData | Measure-Object -Property 'Total Files' -Sum).Sum
$avgErrorRate = ($summaryData | Measure-Object -Property 'Error Rate (%)' -Average).Average

Write-Host "`n=== Summary Statistics ==="
Write-Host "Total files analyzed: $totalFiles"
Write-Host "Total errors found: $totalErrors"
Write-Host "Average error rate: $([math]::Round($avgErrorRate, 2))%"
Write-Host "Projects with errors: $(($summaryData | Where-Object { $_.'Total Errors' -gt 0 }).Count)"

# Top 5 projects with most errors
Write-Host "`n=== Top 5 Projects by Error Count ==="
$summaryData | Sort-Object -Property 'Total Errors' -Descending | Select-Object -First 5 | ForEach-Object {
    Write-Host "  $($_.'Project Name'): $($_.'Total Errors') errors ($($_.'Error Rate (%)'))%"
}
