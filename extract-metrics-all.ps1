# Extract metrics analysis for all projects and consolidate into Excel
# Usage: .\extract-metrics-all.ps1

$ResultsDir = "results"
$OutputDir = "analysis-output"
$OutputExcel = "$OutputDir\metrics-complexity-analysis.xlsx"

# Create output directory if it doesn't exist
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

Write-Host "Starting metrics analysis for all projects..."

# Get all project directories
$projects = Get-ChildItem -Path $ResultsDir -Directory

$allProjectsMetrics = @()

foreach ($project in $projects) {
    $projectName = $project.Name
    Write-Host "Processing: $projectName"
    
    try {
        # Run single project metrics extraction
        & .\extract-metrics-single.ps1 -ProjectName $projectName
        
        # Load the generated metrics
        $metricsPath = "$ResultsDir\$projectName\metrics-analysis.json"
        if (Test-Path $metricsPath) {
            $metrics = Get-Content $metricsPath -Raw | ConvertFrom-Json -AsHashtable
            $allProjectsMetrics += $metrics
        }
    }
    catch {
        Write-Warning "Error processing ${projectName}: $($_.Exception.Message)"
    }
}

# Save consolidated JSON
$consolidatedJson = "$OutputDir\all-projects-metrics-analysis.json"
$allProjectsMetrics | ConvertTo-Json -Depth 10 | Out-File $consolidatedJson -Encoding UTF8

Write-Host "`nGenerating Excel report..."

# Prepare summary data for Excel
$summaryData = @()
foreach ($project in $allProjectsMetrics) {
    $row = [PSCustomObject]@{
        'Project Name' = $project.projectName
        'Analyzed At' = $project.analyzedAt
        'Complexity Score' = $project.complexityScore.overall
        'Complexity Level' = $project.complexityScore.interpretation
    }
    
    # File Coupling metrics
    if ($project.metrics.fileCoupling) {
        $row | Add-Member -NotePropertyName 'Total Files' -NotePropertyValue $project.metrics.fileCoupling.totalFiles
        $row | Add-Member -NotePropertyName 'Files With Coupling' -NotePropertyValue $project.metrics.fileCoupling.filesWithCoupling
        $row | Add-Member -NotePropertyName 'High Coupling Files (>20)' -NotePropertyValue $project.metrics.fileCoupling.highCouplingFiles
        $row | Add-Member -NotePropertyName 'Very High Coupling Files (>50)' -NotePropertyValue $project.metrics.fileCoupling.veryHighCouplingFiles
        $row | Add-Member -NotePropertyName 'Avg Fan-Out' -NotePropertyValue $project.metrics.fileCoupling.averageFanOut
        $row | Add-Member -NotePropertyName 'Avg Fan-In' -NotePropertyValue $project.metrics.fileCoupling.averageFanIn
        $row | Add-Member -NotePropertyName 'Max Coupling' -NotePropertyValue $project.metrics.fileCoupling.maxCoupling
    }
    
    # Functions Per File metrics
    if ($project.metrics.functionsPerFile) {
        $row | Add-Member -NotePropertyName 'Files With Functions' -NotePropertyValue $project.metrics.functionsPerFile.filesWithFunctions
        $row | Add-Member -NotePropertyName 'High Function Files (>10)' -NotePropertyValue $project.metrics.functionsPerFile.highFunctionFiles
        $row | Add-Member -NotePropertyName 'Very High Function Files (>20)' -NotePropertyValue $project.metrics.functionsPerFile.veryHighFunctionFiles
        $row | Add-Member -NotePropertyName 'Extreme Function Files (>50)' -NotePropertyValue $project.metrics.functionsPerFile.extremelyHighFunctionFiles
        $row | Add-Member -NotePropertyName 'Avg Functions/File' -NotePropertyValue $project.metrics.functionsPerFile.averageFunctionsPerFile
        $row | Add-Member -NotePropertyName 'Max Functions' -NotePropertyValue $project.metrics.functionsPerFile.maxFunctions
    }
    
    # Classes Per File metrics
    if ($project.metrics.classesPerFile) {
        $row | Add-Member -NotePropertyName 'Files With Classes' -NotePropertyValue $project.metrics.classesPerFile.filesWithClasses
        $row | Add-Member -NotePropertyName 'High Class Files (>5)' -NotePropertyValue $project.metrics.classesPerFile.highClassFiles
        $row | Add-Member -NotePropertyName 'Very High Class Files (>10)' -NotePropertyValue $project.metrics.classesPerFile.veryHighClassFiles
        $row | Add-Member -NotePropertyName 'Avg Classes/File' -NotePropertyValue $project.metrics.classesPerFile.averageClassesPerFile
        $row | Add-Member -NotePropertyName 'Max Classes' -NotePropertyValue $project.metrics.classesPerFile.maxClasses
    }
    
    $summaryData += $row
}

# Prepare Top 10 Most Coupled Files across all projects
$topCoupledFiles = @()
foreach ($project in $allProjectsMetrics) {
    if ($project.metrics.fileCoupling -and $project.metrics.fileCoupling.top10MostCoupled) {
        foreach ($file in $project.metrics.fileCoupling.top10MostCoupled) {
            $topCoupledFiles += [PSCustomObject]@{
                'Project' = $project.projectName
                'Filename' = $file.filename
                'Fan-Out' = $file.fanOut
                'Fan-In' = $file.fanIn
                'Total Coupling' = $file.total
            }
        }
    }
}
$topCoupledFiles = $topCoupledFiles | Sort-Object -Property 'Total Coupling' -Descending | Select-Object -First 50

# Prepare Top 10 Files with Most Functions across all projects
$topFunctionFiles = @()
foreach ($project in $allProjectsMetrics) {
    if ($project.metrics.functionsPerFile -and $project.metrics.functionsPerFile.top10LargestFiles) {
        foreach ($file in $project.metrics.functionsPerFile.top10LargestFiles) {
            $topFunctionFiles += [PSCustomObject]@{
                'Project' = $project.projectName
                'Filename' = $file.filename
                'Function Count' = $file.functions
            }
        }
    }
}
$topFunctionFiles = $topFunctionFiles | Sort-Object -Property 'Function Count' -Descending | Select-Object -First 50

# Prepare Top 10 Files with Most Classes across all projects
$topClassFiles = @()
foreach ($project in $allProjectsMetrics) {
    if ($project.metrics.classesPerFile -and $project.metrics.classesPerFile.top10LargestFiles) {
        foreach ($file in $project.metrics.classesPerFile.top10LargestFiles) {
            $topClassFiles += [PSCustomObject]@{
                'Project' = $project.projectName
                'Filename' = $file.filename
                'Class Count' = $file.classes
            }
        }
    }
}
$topClassFiles = $topClassFiles | Sort-Object -Property 'Class Count' -Descending | Select-Object -First 50

# Export to Excel if module is available
if (Get-Module -ListAvailable -Name ImportExcel) {
    # Summary sheet
    $summaryData | Export-Excel -Path $OutputExcel -AutoSize -TableName "MetricsOverview" -WorksheetName "Overview" -FreezeTopRow -BoldTopRow
    
    # Top coupled files
    if ($topCoupledFiles.Count -gt 0) {
        $topCoupledFiles | Export-Excel -Path $OutputExcel -AutoSize -TableName "TopCoupledFiles" -WorksheetName "High Coupling Files" -FreezeTopRow -BoldTopRow
    }
    
    # Top function files
    if ($topFunctionFiles.Count -gt 0) {
        $topFunctionFiles | Export-Excel -Path $OutputExcel -AutoSize -TableName "TopFunctionFiles" -WorksheetName "High Function Count" -FreezeTopRow -BoldTopRow
    }
    
    # Top class files
    if ($topClassFiles.Count -gt 0) {
        $topClassFiles | Export-Excel -Path $OutputExcel -AutoSize -TableName "TopClassFiles" -WorksheetName "High Class Count" -FreezeTopRow -BoldTopRow
    }
    
    # Complexity ranking
    $complexityRanking = $summaryData | Sort-Object -Property 'Complexity Score' -Descending | Select-Object 'Project Name', 'Complexity Score', 'Complexity Level', 'High Coupling Files (>20)', 'Very High Function Files (>20)', 'Very High Class Files (>10)'
    $complexityRanking | Export-Excel -Path $OutputExcel -AutoSize -TableName "ComplexityRanking" -WorksheetName "Complexity Ranking" -FreezeTopRow -BoldTopRow
    
    Write-Host "Excel report generated: $OutputExcel"
}
else {
    Write-Warning "ImportExcel module not found."
    Write-Host "Install with: Install-Module -Name ImportExcel -Scope CurrentUser"
    
    # Export to CSV as fallback
    $csvSummary = "$OutputDir\metrics-summary.csv"
    $csvCoupling = "$OutputDir\high-coupling-files.csv"
    $csvFunctions = "$OutputDir\high-function-files.csv"
    $csvClasses = "$OutputDir\high-class-files.csv"
    
    $summaryData | Export-Csv -Path $csvSummary -NoTypeInformation -Encoding UTF8
    if ($topCoupledFiles.Count -gt 0) {
        $topCoupledFiles | Export-Csv -Path $csvCoupling -NoTypeInformation -Encoding UTF8
    }
    if ($topFunctionFiles.Count -gt 0) {
        $topFunctionFiles | Export-Csv -Path $csvFunctions -NoTypeInformation -Encoding UTF8
    }
    if ($topClassFiles.Count -gt 0) {
        $topClassFiles | Export-Csv -Path $csvClasses -NoTypeInformation -Encoding UTF8
    }
    
    Write-Host "CSV files exported to: $OutputDir"
}

Write-Host "`n=== Metrics Analysis Complete ==="
Write-Host "Total projects analyzed: $($allProjectsMetrics.Count)"
Write-Host "Consolidated JSON: $consolidatedJson"
Write-Host "Output directory: $OutputDir"

# Display summary statistics
Write-Host "`n=== Complexity Distribution ==="
$lowComplexity = ($summaryData | Where-Object { $_.'Complexity Score' -lt 20 }).Count
$moderateComplexity = ($summaryData | Where-Object { $_.'Complexity Score' -ge 20 -and $_.'Complexity Score' -lt 40 }).Count
$highComplexity = ($summaryData | Where-Object { $_.'Complexity Score' -ge 40 -and $_.'Complexity Score' -lt 60 }).Count
$veryHighComplexity = ($summaryData | Where-Object { $_.'Complexity Score' -ge 60 }).Count

Write-Host "Low complexity: $lowComplexity projects"
Write-Host "Moderate complexity: $moderateComplexity projects"
Write-Host "High complexity: $highComplexity projects"
Write-Host "Very high complexity: $veryHighComplexity projects"

# Top 5 most complex projects
Write-Host "`n=== Top 5 Most Complex Projects ==="
$summaryData | Sort-Object -Property 'Complexity Score' -Descending | Select-Object -First 5 | ForEach-Object {
    Write-Host "  $($_.'Project Name'): $($_.'Complexity Score') - $($_.'Complexity Level')"
}

# Top 5 least complex projects
Write-Host "`n=== Top 5 Least Complex Projects ==="
$summaryData | Sort-Object -Property 'Complexity Score' | Select-Object -First 5 | ForEach-Object {
    Write-Host "  $($_.'Project Name'): $($_.'Complexity Score') - $($_.'Complexity Level')"
}
