$ErrorActionPreference = "Stop"

$env:NODE_OPTIONS = "--max-old-space-size=16384"

$projects = @(
    "P4-prisma-client", "P5-react-native", "P8-prisma",
    "P15-turbo-linux-64", "P18-storybook-core", "P20-firebase", "P28-react-devtools-core",
    "P29-esbuild-wasm", "P30-msal-browser", "P31-npm", "P35-schematics-angular",
    "P36-apollo-client", "P38-opentelemetry-semantic-conventions", "P40-bootstrap",
    "P47-firebase-database", "P50-esbuild-linux-64", "P54-prettier", "P56-puppeteer-core",
    "P59-playwright-core", "P67-reduxjs-toolkit", "P70-chart.js", "P74-stripe",
    "P76-sass", "P77-google-cloud-firestore", "P78-webpack", "P79-highlight.js",
    "P80-sentry-core", "P83-fp-ts", "P84-html-minifier-terser", "P85-msw",
    "P86-luxon", "P89-rxjs", "P90-faker-js", "P92-moment", "P95-react-router",
    "P96-zod", "P97-playwright", "P98-mongodb", "P99-aws-sdk-client-s3"
)

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$logFile = Join-Path $scriptPath "cyclomatic-complexity.log"
$customResultsPath = Join-Path $scriptPath "custom-results.json"

# Initialize log file
"[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Starting cyclomatic complexity analysis" | Out-File -FilePath $logFile -Encoding UTF8

$success = 0
$failed = 0
$failedProjects = @()
$customResults = @{}

foreach ($project in $projects) {
    $parts = $project -split '-', 2
    $id = $parts[0]
    $name = $parts[1]
    
    Write-Host "[$project]"
    
    $projectPath = Join-Path $scriptPath "repositories" $project
    $projectResultsDir = Join-Path $scriptPath "custom-results" $project
    $customResultsFile = Join-Path $projectResultsDir "cyclomatic-complexity.json"
    
    # Verify project directory exists
    if (-not (Test-Path $projectPath)) {
        $errorMsg = "Project directory not found: $projectPath"
        Write-Host "  FAILED: $errorMsg"
        "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] ERROR [$project]: $errorMsg" | Out-File -FilePath $logFile -Encoding UTF8 -Append
        $failed++
        $failedProjects += $project
        continue
    }
    
    New-Item -ItemType Directory -Path $projectResultsDir -Force | Out-Null
    
    try {
        # Run analysis with custom metric only
        node analyze-cyclomatic.mjs $id $name 2>&1 | Tee-Object -Variable output | Out-Null
        
        # Check if custom results file was created
        if (Test-Path $customResultsFile) {
            Write-Host "  OK"
            $customResults[$project] = "success"
            $success++
            "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] OK [$project]: Analysis completed" | Out-File -FilePath $logFile -Encoding UTF8 -Append
        } else {
            Write-Host "  FAILED: Output file not created"
            "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] ERROR [$project]: Output file not created" | Out-File -FilePath $logFile -Encoding UTF8 -Append
            $failed++
            $failedProjects += $project
        }
    } catch {
        $errorMsg = $_.Exception.Message
        Write-Host "  FAILED: $errorMsg"
        "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] ERROR [$project]: $errorMsg" | Out-File -FilePath $logFile -Encoding UTF8 -Append
        $failed++
        $failedProjects += $project
    }
}

# Aggregate all custom results into single file
$aggregatedResults = @{
    timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    metric = "cyclomatic-complexity"
    totalProjects = $projects.Count
    successful = $success
    failed = $failed
    failedProjects = $failedProjects
    results = $customResults
}

$aggregatedResults | ConvertTo-Json -Depth 10 | Out-File -FilePath $customResultsPath -Encoding UTF8

Write-Host "`n==================================="
Write-Host "Success: $success | Failed: $failed"
Write-Host "Log file: $logFile"
Write-Host "Results file: $customResultsPath"
Write-Host "==================================="

"[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Execution completed. Success: $success, Failed: $failed" | Out-File -FilePath $logFile -Encoding UTF8 -Append
