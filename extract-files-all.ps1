# Extract files.json metrics for all projects and consolidate into Excel
# Usage: .\extract-files-all.ps1

$ResultsDir = "results"
$OutputDir = "analysis-output"
$OutputExcel = "$OutputDir\files-metrics-analysis.xlsx"

# Create output directory if it doesn't exist
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

Write-Host "Starting files metrics analysis for all projects..."

# Get all project directories
$projects = Get-ChildItem -Path $ResultsDir -Directory

$allProjectsFiles = @()

foreach ($project in $projects) {
    $projectName = $project.Name
    Write-Host "Processing: $projectName"
    
    try {
        # Run single project files extraction
        & .\extract-files-single.ps1 -ProjectName $projectName
        
        # Load the generated files analysis
        $filesPath = "$ResultsDir\$projectName\files-analysis.json"
        if (Test-Path $filesPath) {
            $files = Get-Content $filesPath -Raw | ConvertFrom-Json -AsHashtable
            $allProjectsFiles += $files
        }
    }
    catch {
        Write-Warning "Error processing ${projectName}: $($_.Exception.Message)"
    }
}

# Save consolidated JSON
$consolidatedJson = "$OutputDir\all-projects-files-analysis.json"
$allProjectsFiles | ConvertTo-Json -Depth 10 | Out-File $consolidatedJson -Encoding UTF8

Write-Host "`nGenerating Excel report..."

# Prepare overall summary data
$overallSummary = @()
foreach ($project in $allProjectsFiles) {
    $metrics = $project.filesMetrics.overall
    
    $row = [PSCustomObject]@{
        'Project Name' = $project.projectName
        'Analyzed At' = $project.analyzedAt
        'Total Files' = $metrics.totalFiles
        'Unique Extensions' = $metrics.uniqueExtensions
        'Unique Directories' = $metrics.uniqueDirectories
    }
    
    $overallSummary += $row
}

# Prepare extension statistics across all projects
$allExtensions = @{}
foreach ($project in $allProjectsFiles) {
    foreach ($ext in $project.filesMetrics.byExtension) {
        $extension = $ext.extension
        if (-not $allExtensions.ContainsKey($extension)) {
            $allExtensions[$extension] = @{
                projectCount = 0
                totalFiles = 0
            }
        }
        $allExtensions[$extension].projectCount++
        $allExtensions[$extension].totalFiles += $ext.fileCount
    }
}

$extensionSummary = @()
foreach ($ext in $allExtensions.Keys) {
    $stats = $allExtensions[$ext]
    $extensionSummary += [PSCustomObject]@{
        'Extension' = $ext
        'Projects' = $stats.projectCount
        'Total Files' = $stats.totalFiles
        'Avg Files/Project' = [math]::Round($stats.totalFiles / $stats.projectCount, 2)
    }
}
$extensionSummary = $extensionSummary | Sort-Object -Property 'Total Files' -Descending

# Prepare top directories across all projects
$allDirectories = @()
foreach ($project in $allProjectsFiles) {
    if ($project.filesMetrics.byDirectory) {
        foreach ($dir in $project.filesMetrics.byDirectory) {
            $allDirectories += [PSCustomObject]@{
                'Project' = $project.projectName
                'Directory' = $dir.directory
                'File Count' = $dir.fileCount
                'Percentage' = $dir.percentageOfFiles
            }
        }
    }
}
$allDirectories = $allDirectories | Sort-Object -Property 'File Count' -Descending | Select-Object -First 100

# Export to Excel if module is available
if (Get-Module -ListAvailable -Name ImportExcel) {
    # Remove existing file to avoid corruption
    if (Test-Path $OutputExcel) {
        Remove-Item $OutputExcel -Force
    }
    
    # Overall summary
    $overallSummary | Export-Excel -Path $OutputExcel -AutoSize -WorksheetName "Overview" -FreezeTopRow -BoldTopRow -TableStyle Medium2
    
    # Extension statistics
    if ($extensionSummary.Count -gt 0) {
        $extensionSummary | Export-Excel -Path $OutputExcel -AutoSize -WorksheetName "Extensions" -FreezeTopRow -BoldTopRow -TableStyle Medium2
    }
    
    # Top directories
    if ($allDirectories.Count -gt 0) {
        $allDirectories | Export-Excel -Path $OutputExcel -AutoSize -WorksheetName "Top Directories" -FreezeTopRow -BoldTopRow -TableStyle Medium2
    }
    
    # Projects ranking by file count
    $fileCountRanking = $overallSummary | Sort-Object -Property 'Total Files' -Descending
    $fileCountRanking | Export-Excel -Path $OutputExcel -AutoSize -WorksheetName "Ranking" -FreezeTopRow -BoldTopRow -TableStyle Medium2
    
    Write-Host "Excel report generated: $OutputExcel"
}
else {
    Write-Warning "ImportExcel module not found."
    Write-Host "Install with: Install-Module -Name ImportExcel -Scope CurrentUser"
    
    # Export to CSV as fallback
    $csvOverview = "$OutputDir\files-overview.csv"
    $csvExtensions = "$OutputDir\extensions-stats.csv"
    
    $overallSummary | Export-Csv -Path $csvOverview -NoTypeInformation -Encoding UTF8
    if ($extensionSummary.Count -gt 0) {
        $extensionSummary | Export-Csv -Path $csvExtensions -NoTypeInformation -Encoding UTF8
    }
    
    Write-Host "CSV files exported to: $OutputDir"
}

Write-Host "`n=== Files Metrics Analysis Complete ==="
Write-Host "Total projects analyzed: $($allProjectsFiles.Count)"
Write-Host "Consolidated JSON: $consolidatedJson"
Write-Host "Output directory: $OutputDir"

# Display aggregate statistics
$totalFilesAll = ($overallSummary | Measure-Object -Property 'Total Files' -Sum).Sum
$totalExtensions = ($overallSummary | Measure-Object -Property 'Unique Extensions' -Sum).Sum
$avgFilesPerProject = if ($allProjectsFiles.Count -gt 0) { 
    [math]::Round($totalFilesAll / $allProjectsFiles.Count, 2) 
} else { 0 }

Write-Host "`n=== Aggregate Statistics ==="
Write-Host "Total files across all projects: $totalFilesAll"
Write-Host "Total unique extensions: $totalExtensions"
Write-Host "Average files per project: $avgFilesPerProject"
Write-Host "Unique extension types across all projects: $($extensionSummary.Count)"

# Top 5 largest projects by file count
Write-Host "`n=== Top 5 Projects by File Count ==="
$overallSummary | Sort-Object -Property 'Total Files' -Descending | Select-Object -First 5 | ForEach-Object {
    Write-Host "  $($_.'Project Name'): $($_.'Total Files') files ($($_.'Unique Extensions') extensions)"
}

# Top 5 file extensions
Write-Host "`n=== Top 5 Most Common Extensions ==="
$extensionSummary | Select-Object -First 5 | ForEach-Object {
    Write-Host "  $($_.Extension): $($_.'Total Files') files across $($_.Projects) projects"
}
