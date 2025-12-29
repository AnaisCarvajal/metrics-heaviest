param(
    [string]$ResultsPath = ".\results"
)

$projects = Get-ChildItem -Path $ResultsPath -Directory | Select-Object -ExpandProperty Name | Sort-Object
$allErrors = @()
$errorPatterns = @{}

Write-Host "`n=== ANALYZING ERRORS FROM ALL PROJECTS ===" -ForegroundColor Cyan
Write-Host "Processing $(($projects | Measure-Object).Count) projects...`n"

foreach ($project in $projects) {
    $resultsFile = Join-Path -Path $ResultsPath -ChildPath $project -AdditionalChildPath "results.json"
    $errorsFile = Join-Path -Path $ResultsPath -ChildPath $project -AdditionalChildPath "errors.json"
    
    # Skip if results.json doesn't exist
    if (-not (Test-Path $resultsFile)) {
        Write-Host "[$project]" -ForegroundColor Gray -NoNewline
        Write-Host " - No results.json file" -ForegroundColor Gray
        continue
    }
    
    if (Test-Path $errorsFile) {
        try {
            $errorData = Get-Content -Path $errorsFile -Raw | ConvertFrom-Json
            
            # Count errors by category
            $fileErrors = @($errorData.file).Count
            $parseErrors = @($errorData.parse).Count
            $metricErrors = @($errorData.metric).Count
            $traverseErrors = @($errorData.traverse).Count
            $totalErrors = $fileErrors + $parseErrors + $metricErrors + $traverseErrors
            
            if ($totalErrors -gt 0) {
                Write-Host "[$project]" -ForegroundColor Yellow -NoNewline
                Write-Host " - Total: $totalErrors errors" -ForegroundColor White
                
                if ($fileErrors -gt 0) { Write-Host "  └─ File: $fileErrors" -ForegroundColor Red }
                if ($parseErrors -gt 0) { Write-Host "  └─ Parse: $parseErrors" -ForegroundColor Red }
                if ($metricErrors -gt 0) { Write-Host "  └─ Metric: $metricErrors" -ForegroundColor Red }
                if ($traverseErrors -gt 0) { Write-Host "  └─ Traverse: $traverseErrors" -ForegroundColor Red }
                
                # Collect traverse errors for pattern analysis
                if ($traverseErrors -gt 0) {
                    foreach ($error in $errorData.traverse) {
                        # Extract error message pattern
                        if ($error -match "TypeError: (.+?)(?:\$|$)") {
                            $pattern = $matches[1]
                            if (-not $errorPatterns.ContainsKey($pattern)) {
                                $errorPatterns[$pattern] = 0
                            }
                            $errorPatterns[$pattern]++
                        }
                        
                        # Store full error for reporting
                        $allErrors += @{
                            Project = $project
                            Type = "traverse"
                            Message = $error
                        }
                    }
                }
                
                # Collect other errors
                foreach ($type in @("file", "parse", "metric")) {
                    $errors = $errorData.$type
                    if ($errors -and ($errors | Measure-Object).Count -gt 0) {
                        foreach ($error in $errors) {
                            $allErrors += @{
                                Project = $project
                                Type = $type
                                Message = $error
                            }
                        }
                    }
                }
            } else {
                Write-Host "[$project]" -ForegroundColor Green -NoNewline
                Write-Host " - No errors" -ForegroundColor Gray
            }
        } catch {
            Write-Host "[$project]" -ForegroundColor Red -NoNewline
            Write-Host " - ERROR reading file: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "[$project]" -ForegroundColor Green -NoNewline
        Write-Host " - No errors detected" -ForegroundColor Gray
    }
}

# Summary Section
Write-Host "`n" -ForegroundColor Cyan
Write-Host "=== ERROR SUMMARY ===" -ForegroundColor Cyan
Write-Host "Total errors across all projects: $($allErrors.Count)"
$projectsWithErrors = @($allErrors | Select-Object -ExpandProperty Project -Unique)
Write-Host "Projects with errors: $($projectsWithErrors.Count)"

# Most common error type
if ($allErrors.Count -gt 0) {
    Write-Host "`n=== MOST COMMON ERROR PATTERNS ===" -ForegroundColor Cyan
    $sortedPatterns = $errorPatterns.GetEnumerator() | Sort-Object -Property Value -Descending | Select-Object -First 10

    foreach ($pattern in $sortedPatterns) {
        $percentage = [math]::Round(($pattern.Value / $allErrors.Count) * 100, 2)
        Write-Host "$($pattern.Value) occurrences ($percentage%) - " -ForegroundColor Yellow -NoNewline
        Write-Host "$($pattern.Key)" -ForegroundColor White
    }

    # Error breakdown by type
    Write-Host "`n=== ERROR BREAKDOWN BY TYPE ===" -ForegroundColor Cyan
    $errorsByType = $allErrors | Group-Object -Property Type
    foreach ($typeGroup in $errorsByType) {
        $percentage = [math]::Round(($typeGroup.Count / $allErrors.Count) * 100, 2)
        Write-Host "$($typeGroup.Name): $($typeGroup.Count) errors ($percentage%)" -ForegroundColor Gray
    }

    # Projects with most errors
    Write-Host "`n=== TOP 10 PROJECTS WITH MOST ERRORS ===" -ForegroundColor Cyan
    $topProjects = $allErrors | Group-Object -Property Project | Sort-Object -Property Count -Descending | Select-Object -First 10
    foreach ($proj in $topProjects) {
        Write-Host "$($proj.Name): $($proj.Count) errors" -ForegroundColor Gray
    }
    
    # Export detailed report
    $reportPath = ".\error-analysis-report.json"
    $report = @{
        timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        totalErrors = $allErrors.Count
        projectsWithErrors = $projectsWithErrors.Count
        errorsByType = @{
            file = ($allErrors | Where-Object { $_.Type -eq "file" } | Measure-Object).Count
            parse = ($allErrors | Where-Object { $_.Type -eq "parse" } | Measure-Object).Count
            metric = ($allErrors | Where-Object { $_.Type -eq "metric" } | Measure-Object).Count
            traverse = ($allErrors | Where-Object { $_.Type -eq "traverse" } | Measure-Object).Count
        }
        mostCommonPatterns = ($sortedPatterns | ForEach-Object { @{ pattern = $_.Key; count = $_.Value } })
        errorsByProject = ($allErrors | Group-Object -Property Project | ForEach-Object { @{ project = $_.Name; count = $_.Count } } | Sort-Object -Property count -Descending)
    }

    $report | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportPath -Encoding UTF8
    Write-Host "`nDetailed report exported to: $reportPath`n" -ForegroundColor Green

    # Export detailed errors (CSV)
    $csvPath = ".\error-analysis-detailed.csv"
    $allErrors | ConvertTo-Csv -NoTypeInformation | Out-File -FilePath $csvPath -Encoding UTF8
    Write-Host "Detailed errors exported to: $csvPath`n" -ForegroundColor Green
} else {
    Write-Host "No errors found across all projects!`n" -ForegroundColor Green
}
