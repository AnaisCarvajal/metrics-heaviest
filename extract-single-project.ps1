# Extract valuable information from a single project's results
# Usage: .\extract-single-project.ps1 -ProjectName "P1-googleapis"

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectName
)

$ResultsPath = "results\$ProjectName"
$OutputPath = "results\$ProjectName\analysis-summary.json"

if (-not (Test-Path $ResultsPath)) {
    Write-Error "Project path not found: $ResultsPath"
    exit 1
}

Write-Host "Processing project: $ProjectName"

# Extract errors with sanitized paths
$errorsData = Get-Content "$ResultsPath\errors.json" -Raw | ConvertFrom-Json -AsHashtable

# Function to sanitize paths - remove user-specific directories
function Sanitize-Path {
    param([string]$path)
    $path = $path -replace [regex]::Escape($PSScriptRoot), '[WORKSPACE]'
    $path = $path -replace 'C:\\Users\\[^\\]+', '[USER]'
    $path = $path -replace '\\repositories\\', '\repos\'
    return $path
}

# Process errors - group by error type and show unique examples
$errorSummary = @{
    file = @()
    parse = @()
    metric = @()
    traverse = @()
}

foreach ($errorType in @('file', 'parse', 'metric', 'traverse')) {
    $errors = $errorsData.$errorType
    if ($errors -and $errors.Count -gt 0) {
        # Group errors by error message pattern
        $errorGroups = @{}
        
        foreach ($error in $errors) {
            $sanitized = Sanitize-Path $error
            
            # Extract error pattern (everything after the last "->")
            if ($sanitized -match '-> (.+)$') {
                $errorMsg = $matches[1]
            } else {
                $errorMsg = $sanitized
            }
            
            # Extract core error type
            if ($errorMsg -match '(TypeError|SyntaxError|ReferenceError|Error): (.+)') {
                $errorPattern = "$($matches[1]): $($matches[2])"
            } else {
                $errorPattern = $errorMsg
            }
            
            if (-not $errorGroups.ContainsKey($errorPattern)) {
                $errorGroups[$errorPattern] = @{
                    pattern = $errorPattern
                    count = 0
                    examples = @()
                }
            }
            
            $errorGroups[$errorPattern].count++
            
            # Store only first 3 examples
            if ($errorGroups[$errorPattern].examples.Count -lt 3) {
                $errorGroups[$errorPattern].examples += $sanitized
            }
        }
        
        $errorSummary.$errorType = $errorGroups.Values | ForEach-Object {
            @{
                pattern = $_.pattern
                occurrences = $_.count
                examples = $_.examples
            }
        }
    }
}

# Get project summary from results.json
$resultsData = Get-Content "$ResultsPath\results.json" -Raw | ConvertFrom-Json -AsHashtable

# Count files with specific metrics issues if available
$filesWithIssues = @{
    highClassesPerFile = 0
    highFunctionsPerFile = 0
    highFileCoupling = 0
}

if (Test-Path "$ResultsPath\classes-per-file.json") {
    $classesData = Get-Content "$ResultsPath\classes-per-file.json" -Raw | ConvertFrom-Json -AsHashtable
    $filesWithIssues.highClassesPerFile = ($classesData | Where-Object { $_.classCount -gt 5 }).Count
}

if (Test-Path "$ResultsPath\functions-per-file.json") {
    $functionsData = Get-Content "$ResultsPath\functions-per-file.json" -Raw | ConvertFrom-Json -AsHashtable
    $filesWithIssues.highFunctionsPerFile = ($functionsData | Where-Object { $_.functionCount -gt 10 }).Count
}

if (Test-Path "$ResultsPath\file-coupling.json") {
    $couplingData = Get-Content "$ResultsPath\file-coupling.json" -Raw | ConvertFrom-Json -AsHashtable
    $filesWithIssues.highFileCoupling = ($couplingData | Where-Object { $_.couplingCount -gt 20 }).Count
}

# Build final summary
$summary = @{
    project = @{
        id = $resultsData.projectId
        name = $resultsData.projectName
        analyzedAt = $resultsData.analyzedAt
        totalFiles = $resultsData.totalFiles
    }
    errors = @{
        summary = @{
            totalFileErrors = $errorsData.file.Count
            totalParseErrors = $errorsData.parse.Count
            totalMetricErrors = $errorsData.metric.Count
            totalTraverseErrors = $errorsData.traverse.Count
            total = $errorsData.file.Count + $errorsData.parse.Count + $errorsData.metric.Count + $errorsData.traverse.Count
        }
        details = $errorSummary
    }
    metrics = @{
        filesWithHighComplexity = $filesWithIssues
        metricsAvailable = $resultsData.metricsAvailable
    }
}

# Save to JSON
$summary | ConvertTo-Json -Depth 10 | Out-File $OutputPath -Encoding UTF8

Write-Host "Analysis complete. Output saved to: $OutputPath"
Write-Host "Total errors: $($summary.errors.summary.total)"
