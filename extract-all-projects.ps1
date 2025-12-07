# Extract valuable information from ALL projects and consolidate into Excel
# Usage: .\extract-all-projects.ps1

$ResultsDir = "results"
$OutputDir = "analysis-output"
$OutputExcel = "$OutputDir\metrics-analysis.xlsx"

# Create output directory
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

Write-Host "Starting analysis of all projects..."

# Get all project directories
$projects = Get-ChildItem -Path $ResultsDir -Directory

$allProjectsData = @()

foreach ($project in $projects) {
    $projectName = $project.Name
    Write-Host "Processing: $projectName"
    
    try {
        # Run single project extraction
        & .\extract-single-project.ps1 -ProjectName $projectName
        
        # Load the generated summary
        $summaryPath = "$ResultsDir\$projectName\analysis-summary.json"
        if (Test-Path $summaryPath) {
            $summary = Get-Content $summaryPath -Raw | ConvertFrom-Json -AsHashtable
            $allProjectsData += $summary
        }
    }
    catch {
        Write-Warning "Error processing ${projectName}: $($_.Exception.Message)"
    }
}

# Save consolidated JSON
$consolidatedJson = "$OutputDir\all-projects-analysis.json"
$allProjectsData | ConvertTo-Json -Depth 10 | Out-File $consolidatedJson -Encoding UTF8

Write-Host "`nGenerating Excel report..."

# Prepare data for Excel export
$excelData = @()

foreach ($project in $allProjectsData) {
    $row = [PSCustomObject]@{
        'Project ID' = $project.project.id
        'Project Name' = $project.project.name
        'Analyzed At' = $project.project.analyzedAt
        'Total Files' = $project.project.totalFiles
        'File Errors' = $project.errors.summary.totalFileErrors
        'Parse Errors' = $project.errors.summary.totalParseErrors
        'Metric Errors' = $project.errors.summary.totalMetricErrors
        'Traverse Errors' = $project.errors.summary.totalTraverseErrors
        'Total Errors' = $project.errors.summary.total
        'High Classes Per File' = $project.metrics.filesWithHighComplexity.highClassesPerFile
        'High Functions Per File' = $project.metrics.filesWithHighComplexity.highFunctionsPerFile
        'High File Coupling' = $project.metrics.filesWithHighComplexity.highFileCoupling
        'Metrics Available' = ($project.metrics.metricsAvailable -join ', ')
    }
    $excelData += $row
}

# Export to Excel using ImportExcel module
# Check if ImportExcel module is available
if (Get-Module -ListAvailable -Name ImportExcel) {
    $excelData | Export-Excel -Path $OutputExcel -AutoSize -TableName "MetricsAnalysis" -WorksheetName "Summary" -FreezeTopRow -BoldTopRow
    
    # Create error details sheet
    $errorDetails = @()
    foreach ($project in $allProjectsData) {
        foreach ($errorType in @('file', 'parse', 'metric', 'traverse')) {
            $errors = $project.errors.details.$errorType
            if ($errors -and $errors.Count -gt 0) {
                foreach ($error in $errors) {
                    $errorDetails += [PSCustomObject]@{
                        'Project' = $project.project.name
                        'Error Type' = $errorType
                        'Pattern' = $error.pattern
                        'Occurrences' = $error.occurrences
                        'Example 1' = if ($error.examples.Count -gt 0) { $error.examples[0] } else { '' }
                        'Example 2' = if ($error.examples.Count -gt 1) { $error.examples[1] } else { '' }
                        'Example 3' = if ($error.examples.Count -gt 2) { $error.examples[2] } else { '' }
                    }
                }
            }
        }
    }
    
    if ($errorDetails.Count -gt 0) {
        $errorDetails | Export-Excel -Path $OutputExcel -AutoSize -WorksheetName "Error Details" -FreezeTopRow -BoldTopRow
    }
    
    Write-Host "Excel report generated: $OutputExcel"
}
else {
    Write-Warning "ImportExcel module not found. Installing..."
    Write-Host "Run: Install-Module -Name ImportExcel -Scope CurrentUser"
    Write-Host "Then re-run this script to generate the Excel file."
    
    # Export to CSV as fallback
    $csvPath = "$OutputDir\metrics-analysis.csv"
    $excelData | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
    
    $csvErrorPath = "$OutputDir\error-details.csv"
    if ($errorDetails.Count -gt 0) {
        $errorDetails | Export-Csv -Path $csvErrorPath -NoTypeInformation -Encoding UTF8
    }
    
    Write-Host "CSV files exported to: $OutputDir"
}

Write-Host "`n=== Analysis Complete ==="
Write-Host "Total projects analyzed: $($allProjectsData.Count)"
Write-Host "Consolidated JSON: $consolidatedJson"
Write-Host "Excel/CSV output: $OutputDir"

# Display summary statistics
$totalErrors = ($allProjectsData | Measure-Object -Property { $_.errors.summary.total } -Sum).Sum
$totalFiles = ($allProjectsData | Measure-Object -Property { $_.project.totalFiles } -Sum).Sum

Write-Host "`n=== Summary Statistics ==="
Write-Host "Total files analyzed: $totalFiles"
Write-Host "Total errors found: $totalErrors"
Write-Host "Average errors per project: $([math]::Round($totalErrors / $allProjectsData.Count, 2))"
