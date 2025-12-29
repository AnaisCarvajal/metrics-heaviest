$ErrorActionPreference = "Stop"

$env:NODE_OPTIONS = "--max-old-space-size=16384"

$projects = @(
    "P1-googleapis",
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

$success = 0
$failed = 0
$executionLog = @()

foreach ($project in $projects) {
    $parts = $project -split '-', 2
    $id = $parts[0]
    $name = $parts[1]
    
    Write-Host "[$project]"
    
    $projectResultsDir = "C:\Users\anais\OneDrive\Documentos\Github\Metrics2\results\$project"
    $resultsFile = Join-Path $projectResultsDir 'results.json'
    
    # Check if results.json already exists
    if (Test-Path $resultsFile) {
        Write-Host "  SKIP: Already analyzed"
        continue
    }
    
    node analyze.mjs $id $name
    
    # Verify results.json was created
    if (Test-Path $resultsFile) {
        Write-Host "  OK"
        $success++
    } else {
        Write-Host "  FAILED"
        $failed++
    }
}

Write-Host "`nSuccess: $success | Failed: $failed"