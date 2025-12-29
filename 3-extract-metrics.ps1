$ErrorActionPreference = "Stop"

$resultsDir = "C:\Users\anais\OneDrive\Documentos\Github\Metrics2\results"
$output = @()

# Get all project directories
$projects = Get-ChildItem -Path $resultsDir -Directory | Where-Object { $_.Name -match '^P\d+' }

Write-Host "Processing $(($projects | Measure-Object).Count) projects..."
Write-Host ""

foreach ($project in $projects) {
    $resultsFile = Join-Path $project.FullName "results.json"
    $errorsFile = Join-Path $project.FullName "errors.json"
    
    # Skip if results.json doesn't exist
    if (-not (Test-Path $resultsFile)) {
        continue
    }
    
    # Extract project ID and name
    $parts = $project.Name -split '-', 2
    $projectId = $parts[0]
    $projectName = $parts[1]
    
    Write-Host "[$projectId-$projectName]" -ForegroundColor Cyan
    
    # Read results.json
    $results = Get-Content $resultsFile | ConvertFrom-Json
    
    # Extract basic info
    $totalFiles = $results.totalFiles ?? 0
    $metricsAvailable = $results.metricsAvailable ?? @()
    $analyzedAt = $results.analyzedAt ?? ""
    
    # Extract execution info
    $executionTimeMs = $results.execution.timeMs ?? 0
    $executionTimeSec = $results.execution.timeSec ?? 0
    
    # Extract size info
    $totalSizeBytes = $results.size.totalBytes ?? 0
    $totalSizeKB = $results.size.totalKB ?? 0
    $totalSizeMB = $results.size.totalMB ?? 0
    $fileBreakdown = $results.size.fileBreakdown ?? @{}
    
    # Read errors.json to count errors
    $errorCount = 0
    $traverseErrors = 0
    $parseErrors = 0
    $fileErrors = 0
    $metricErrors = 0
    $mostCommonError = "None"
    
    if (Test-Path $errorsFile) {
        try {
            $errorData = Get-Content $errorsFile | ConvertFrom-Json
            $fileErrors = @($errorData.file).Count
            $parseErrors = @($errorData.parse).Count
            $metricErrors = @($errorData.metric).Count
            $traverseErrors = @($errorData.traverse).Count
            $errorCount = $fileErrors + $parseErrors + $metricErrors + $traverseErrors
            
            # Get most common error pattern
            if ($traverseErrors -gt 0 -and $errorData.traverse.Count -gt 0) {
                $firstError = $errorData.traverse[0]
                if ($firstError -match "TypeError: (.+?)(?:\$|$)") {
                    $mostCommonError = $matches[1]
                }
            }
        } catch {
            # Silently skip if error reading errors.json
        }
    }
    
    Write-Host "  Total files: $totalFiles"
    Write-Host "  Metrics: $($metricsAvailable.Count) available"
    Write-Host "  Execution time: ${executionTimeSec}s (${executionTimeMs}ms)"
    Write-Host "  Result size: $([math]::Round($totalSizeMB, 3))MB ($([math]::Round($totalSizeKB, 2))KB)"
    Write-Host "  Errors: $errorCount (File: $fileErrors | Parse: $parseErrors | Metric: $metricErrors | Traverse: $traverseErrors)"
    if ($mostCommonError -ne "None") {
        Write-Host "  Most common error: $mostCommonError" -ForegroundColor Yellow
    }
    Write-Host ""
    
    # Add to output
    $output += [PSCustomObject]@{
        ProjectID           = $projectId
        ProjectName         = $projectName
        TotalFiles          = [int]$totalFiles
        MetricsCount        = [int]$metricsAvailable.Count
        ExecutionTimeMs     = [int]$executionTimeMs
        ExecutionTimeSec    = [double]$executionTimeSec
        TotalSizeBytes      = [int]$totalSizeBytes
        TotalSizeKB         = [double]$totalSizeKB
        TotalSizeMB         = [double]$totalSizeMB
        FileErrors          = [int]$fileErrors
        ParseErrors         = [int]$parseErrors
        MetricErrors        = [int]$metricErrors
        TraverseErrors      = [int]$traverseErrors
        TotalErrors         = [int]$errorCount
        MostCommonError     = $mostCommonError
        AnalyzedAt          = $analyzedAt
    }
}

Write-Host "=== SUMMARY ===" -ForegroundColor Green
Write-Host "Total projects processed: $(($output | Measure-Object).Count)"
Write-Host ""

# Display table
if ($output.Count -gt 0) {
    $output | Format-Table -Property ProjectID, ProjectName, TotalFiles, ExecutionTimeSec, TotalSizeMB, TotalErrors -AutoSize
    
    # Export to JSON
    $jsonPath = Join-Path $resultsDir "metrics-extraction-report.json"
    $output | ConvertTo-Json -Depth 3 | Out-File -FilePath $jsonPath -Encoding UTF8
    Write-Host "Report exported to: $jsonPath" -ForegroundColor Green
    
    # Export to CSV
    $csvPath = Join-Path $resultsDir "metrics-extraction-report.csv"
    $output | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
    Write-Host "CSV report exported to: $csvPath" -ForegroundColor Green
    
    # Display statistics
    Write-Host ""
    Write-Host "=== STATISTICS ===" -ForegroundColor Yellow
    Write-Host "Average execution time: $([math]::Round(($output | Measure-Object -Property ExecutionTimeSec -Average).Average, 2))s"
    Write-Host "Average result size: $([math]::Round(($output | Measure-Object -Property TotalSizeMB -Average).Average, 2))MB"
    Write-Host "Total errors across all projects: $(($output | Measure-Object -Property TotalErrors -Sum).Sum)"
    Write-Host "Projects with errors: $(($output | Where-Object { $_.TotalErrors -gt 0 } | Measure-Object).Count)"
} else {
    Write-Host "No projects found with results files." -ForegroundColor Yellow
}
