# Extract files.json metrics for a single project
# Usage: .\extract-files-single.ps1 -ProjectName "P1-googleapis"

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectName
)

$ResultsPath = "results\$ProjectName"
$FilesJsonPath = "$ResultsPath\files.json"
$OutputFile = "$ResultsPath\files-analysis.json"

if (-not (Test-Path $FilesJsonPath)) {
    Write-Error "files.json not found: $FilesJsonPath"
    exit 1
}

Write-Host "Extracting files metrics for project: $ProjectName"

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
    if ([string]::IsNullOrWhiteSpace($path)) {
        return "unknown"
    }
    $filename = Split-Path $path -Leaf
    if ($filename) {
        return $filename
    } else {
        return "unknown"
    }
}

# Function to get file extension
function Get-FileExtension {
    param([string]$filename)
    if ([string]::IsNullOrWhiteSpace($filename) -or $filename -eq "unknown") {
        return "no-extension"
    }
    $ext = [System.IO.Path]::GetExtension($filename)
    if ($ext) {
        return $ext.ToLower()
    } else {
        return "no-extension"
    }
}

# Load files data
$filesData = Get-Content $FilesJsonPath -Raw | ConvertFrom-Json

# Initialize analysis
$analysis = @{
    projectName = $ProjectName
    analyzedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    filesMetrics = @{}
}

# Check if result is array or object
if ($filesData.result -isnot [System.Array]) {
    Write-Error "files.json result is not in expected format"
    exit 1
}

# Process files (result is array of file paths)
$filesList = @()
$extensionStats = @{}
$directoryStats = @{}

foreach ($filePath in $filesData.result) {
    if ([string]::IsNullOrWhiteSpace($filePath)) {
        continue
    }
    
    $sanitizedPath = Sanitize-Path $filePath
    $filename = Get-FileName $filePath
    $extension = Get-FileExtension $filename
    
    # Extract directory
    $directory = Split-Path $filePath -Parent
    if ($directory) {
        $directory = Sanitize-Path $directory
        # Get relative directory from repository root
        if ($directory -match '\\repos\\[^\\]+\\(.+)$') {
            $relativeDir = $matches[1]
        } else {
            $relativeDir = "root"
        }
    } else {
        $relativeDir = "root"
    }
    
    $filesList += [PSCustomObject]@{
        file = $sanitizedPath
        filename = $filename
        extension = $extension
        directory = $relativeDir
    }
    
    # Update extension statistics
    if (-not $extensionStats.ContainsKey($extension)) {
        $extensionStats[$extension] = 0
    }
    $extensionStats[$extension]++
    
    # Update directory statistics
    if (-not $directoryStats.ContainsKey($relativeDir)) {
        $directoryStats[$relativeDir] = 0
    }
    $directoryStats[$relativeDir]++
}

# Calculate overall statistics
$totalFiles = $filesList.Count

# Build extension statistics array
$extensionStatsArray = @()
foreach ($ext in $extensionStats.Keys) {
    $count = $extensionStats[$ext]
    $extensionStatsArray += [PSCustomObject]@{
        extension = $ext
        fileCount = $count
        percentageOfFiles = [math]::Round(($count / $totalFiles) * 100, 2)
    }
}
$extensionStatsArray = $extensionStatsArray | Sort-Object -Property fileCount -Descending

# Build directory statistics array
$directoryStatsArray = @()
foreach ($dir in $directoryStats.Keys) {
    $count = $directoryStats[$dir]
    $directoryStatsArray += [PSCustomObject]@{
        directory = $dir
        fileCount = $count
        percentageOfFiles = [math]::Round(($count / $totalFiles) * 100, 2)
    }
}
$directoryStatsArray = $directoryStatsArray | Sort-Object -Property fileCount -Descending

# Populate analysis object
$analysis.filesMetrics = @{
    overall = @{
        totalFiles = $totalFiles
        uniqueExtensions = $extensionStats.Keys.Count
        uniqueDirectories = $directoryStats.Keys.Count
    }
    byExtension = $extensionStatsArray
    byDirectory = $directoryStatsArray | Select-Object -First 20
    filesList = $filesList | Select-Object filename, extension, directory
}

# Save to JSON
$analysis | ConvertTo-Json -Depth 10 | Out-File $OutputFile -Encoding UTF8

Write-Host "Files analysis complete. Output saved to: $OutputFile"
Write-Host "Total Files: $totalFiles"
Write-Host "Unique Extensions: $($extensionStats.Keys.Count)"
Write-Host "Unique Directories: $($directoryStats.Keys.Count)"
