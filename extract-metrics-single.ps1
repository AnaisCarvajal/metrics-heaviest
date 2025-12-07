# Extract metrics analysis for a single project
# Usage: .\extract-metrics-single.ps1 -ProjectName "P1-googleapis"

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectName
)

$ResultsPath = "results\$ProjectName"
$OutputFile = "$ResultsPath\metrics-analysis.json"

if (-not (Test-Path $ResultsPath)) {
    Write-Error "Project path not found: $ResultsPath"
    exit 1
}

Write-Host "Extracting metrics for project: $ProjectName"

# Function to sanitize paths
function Sanitize-Path {
    param([string]$path)
    $path = $path -replace 'C:\\Users\\[^\\]+', '[USER]'
    $path = $path -replace '\\OneDrive\\[^\\]+\\[^\\]+\\[^\\]+\\Metrics2', '[WORKSPACE]'
    $path = $path -replace '\\repositories\\', '\repos\'
    return $path
}

# Function to extract filename
function Get-FileName {
    param([string]$path)
    return Split-Path $path -Leaf
}

# Initialize analysis object
$analysis = @{
    projectName = $ProjectName
    analyzedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    metrics = @{}
}

# Process File Coupling
if (Test-Path "$ResultsPath\file-coupling.json") {
    Write-Host "Processing file coupling..."
    $fileCouplingData = Get-Content "$ResultsPath\file-coupling.json" -Raw | ConvertFrom-Json -AsHashtable
    
    $couplingList = @()
    foreach ($entry in $fileCouplingData.result.GetEnumerator()) {
        $sanitizedPath = Sanitize-Path $entry.Key
        $couplingList += [PSCustomObject]@{
            file = $sanitizedPath
            filename = Get-FileName $entry.Key
            fanOut = $entry.Value.fanOut.Count
            fanIn = $entry.Value.fanIn.Count
            totalCoupling = $entry.Value.fanOut.Count + $entry.Value.fanIn.Count
        }
    }
    
    $couplingList = $couplingList | Sort-Object -Property totalCoupling -Descending
    
    $analysis.metrics.fileCoupling = @{
        totalFiles = $couplingList.Count
        filesWithCoupling = ($couplingList | Where-Object { $_.totalCoupling -gt 0 }).Count
        highCouplingFiles = ($couplingList | Where-Object { $_.totalCoupling -gt 20 }).Count
        veryHighCouplingFiles = ($couplingList | Where-Object { $_.totalCoupling -gt 50 }).Count
        averageFanOut = [math]::Round(($couplingList | Measure-Object -Property fanOut -Average).Average, 2)
        averageFanIn = [math]::Round(($couplingList | Measure-Object -Property fanIn -Average).Average, 2)
        maxCoupling = ($couplingList | Measure-Object -Property totalCoupling -Maximum).Maximum
        top10MostCoupled = $couplingList | Select-Object -First 10 | ForEach-Object {
            @{
                filename = $_.filename
                fanOut = $_.fanOut
                fanIn = $_.fanIn
                total = $_.totalCoupling
            }
        }
    }
}

# Process Functions Per File
if (Test-Path "$ResultsPath\functions-per-file.json") {
    Write-Host "Processing functions per file..."
    $functionsData = Get-Content "$ResultsPath\functions-per-file.json" -Raw | ConvertFrom-Json -AsHashtable
    
    $functionsList = @()
    foreach ($entry in $functionsData.result.GetEnumerator()) {
        $sanitizedPath = Sanitize-Path $entry.Key
        $functionCount = if ($entry.Value -is [System.Collections.IDictionary]) { 
            $entry.Value.Keys.Count 
        } else { 
            0 
        }
        
        $functionsList += [PSCustomObject]@{
            file = $sanitizedPath
            filename = Get-FileName $entry.Key
            functionCount = $functionCount
        }
    }
    
    $functionsList = $functionsList | Sort-Object -Property functionCount -Descending
    
    $analysis.metrics.functionsPerFile = @{
        totalFiles = $functionsList.Count
        filesWithFunctions = ($functionsList | Where-Object { $_.functionCount -gt 0 }).Count
        highFunctionFiles = ($functionsList | Where-Object { $_.functionCount -gt 10 }).Count
        veryHighFunctionFiles = ($functionsList | Where-Object { $_.functionCount -gt 20 }).Count
        extremelyHighFunctionFiles = ($functionsList | Where-Object { $_.functionCount -gt 50 }).Count
        averageFunctionsPerFile = [math]::Round(($functionsList | Measure-Object -Property functionCount -Average).Average, 2)
        maxFunctions = ($functionsList | Measure-Object -Property functionCount -Maximum).Maximum
        top10LargestFiles = $functionsList | Select-Object -First 10 | ForEach-Object {
            @{
                filename = $_.filename
                functions = $_.functionCount
            }
        }
    }
}

# Process Classes Per File (if available and not too large)
$classesFile = "$ResultsPath\classes-per-file.json"
if (Test-Path $classesFile) {
    $fileSize = (Get-Item $classesFile).Length / 1MB
    if ($fileSize -lt 50) {
        Write-Host "Processing classes per file..."
        try {
            $classesData = Get-Content $classesFile -Raw | ConvertFrom-Json -AsHashtable
            
            $classesList = @()
            foreach ($entry in $classesData.result.GetEnumerator()) {
                $sanitizedPath = Sanitize-Path $entry.Key
                $classCount = if ($entry.Value -is [System.Collections.IDictionary]) { 
                    $entry.Value.Keys.Count 
                } else { 
                    0 
                }
                
                $classesList += [PSCustomObject]@{
                    file = $sanitizedPath
                    filename = Get-FileName $entry.Key
                    classCount = $classCount
                }
            }
            
            $classesList = $classesList | Sort-Object -Property classCount -Descending
            
            $analysis.metrics.classesPerFile = @{
                totalFiles = $classesList.Count
                filesWithClasses = ($classesList | Where-Object { $_.classCount -gt 0 }).Count
                highClassFiles = ($classesList | Where-Object { $_.classCount -gt 5 }).Count
                veryHighClassFiles = ($classesList | Where-Object { $_.classCount -gt 10 }).Count
                averageClassesPerFile = [math]::Round(($classesList | Measure-Object -Property classCount -Average).Average, 2)
                maxClasses = ($classesList | Measure-Object -Property classCount -Maximum).Maximum
                top10LargestFiles = $classesList | Select-Object -First 10 | ForEach-Object {
                    @{
                        filename = $_.filename
                        classes = $_.classCount
                    }
                }
            }
        }
        catch {
            Write-Warning "Could not process classes-per-file.json: $($_.Exception.Message)"
        }
    }
    else {
        Write-Warning "classes-per-file.json is too large ($([math]::Round($fileSize, 2)) MB), skipping"
    }
}

# Calculate complexity score
$complexityScore = 0
$factors = @()

if ($analysis.metrics.fileCoupling) {
    $couplingScore = [math]::Min(($analysis.metrics.fileCoupling.highCouplingFiles / $analysis.metrics.fileCoupling.totalFiles) * 100, 100)
    $complexityScore += $couplingScore * 0.4
    $factors += "High coupling: $([math]::Round($couplingScore, 2))%"
}

if ($analysis.metrics.functionsPerFile) {
    $functionScore = [math]::Min(($analysis.metrics.functionsPerFile.veryHighFunctionFiles / $analysis.metrics.functionsPerFile.totalFiles) * 100, 100)
    $complexityScore += $functionScore * 0.4
    $factors += "High function count: $([math]::Round($functionScore, 2))%"
}

if ($analysis.metrics.classesPerFile) {
    $classScore = [math]::Min(($analysis.metrics.classesPerFile.veryHighClassFiles / $analysis.metrics.classesPerFile.totalFiles) * 100, 100)
    $complexityScore += $classScore * 0.2
    $factors += "High class count: $([math]::Round($classScore, 2))%"
}

$analysis.complexityScore = @{
    overall = [math]::Round($complexityScore, 2)
    factors = $factors
    interpretation = if ($complexityScore -lt 20) { "Low complexity" }
                     elseif ($complexityScore -lt 40) { "Moderate complexity" }
                     elseif ($complexityScore -lt 60) { "High complexity" }
                     else { "Very high complexity" }
}

# Save to JSON
$analysis | ConvertTo-Json -Depth 10 | Out-File $OutputFile -Encoding UTF8

Write-Host "Metrics analysis complete. Output saved to: $OutputFile"
Write-Host "Complexity Score: $($analysis.complexityScore.overall) - $($analysis.complexityScore.interpretation)"
