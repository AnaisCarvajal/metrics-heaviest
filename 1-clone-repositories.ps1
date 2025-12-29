$ErrorActionPreference = "Stop"

$projects = @(
    @{ID="P1"; Name="googleapis"; Repo="https://github.com/googleapis/google-api-nodejs-client.git"},
    @{ID="P4"; Name="prisma-client"; Repo="https://github.com/prisma/prisma.git"},
    @{ID="P5"; Name="react-native"; Repo="https://github.com/facebook/react-native.git"},
    @{ID="P8"; Name="prisma"; Repo="https://github.com/prisma/prisma.git"},
    @{ID="P15"; Name="turbo-linux-64"; Repo="https://github.com/vercel/turbo.git"},
    @{ID="P18"; Name="storybook-core"; Repo="https://github.com/storybookjs/storybook.git"},
    @{ID="P20"; Name="firebase"; Repo="https://github.com/firebase/firebase-js-sdk.git"},
    @{ID="P28"; Name="react-devtools-core"; Repo="https://github.com/facebook/react"},
    @{ID="P29"; Name="esbuild-wasm"; Repo="https://github.com/evanw/esbuild.git"},
    @{ID="P30"; Name="msal-browser"; Repo="https://github.com/AzureAD/microsoft-authentication-library-for-js.git"},
    @{ID="P31"; Name="npm"; Repo="https://github.com/npm/cli.git"},
    @{ID="P35"; Name="schematics-angular"; Repo="https://github.com/angular/angular-cli.git"},
    @{ID="P36"; Name="apollo-client"; Repo="https://github.com/apollographql/apollo-client.git"},
    @{ID="P38"; Name="opentelemetry-semantic-conventions"; Repo="https://github.com/open-telemetry/opentelemetry-js.git"},
    @{ID="P40"; Name="bootstrap"; Repo="https://github.com/twbs/bootstrap.git"},
    @{ID="P47"; Name="firebase-database"; Repo="https://github.com/firebase/firebase-js-sdk.git"},
    @{ID="P50"; Name="esbuild-linux-64"; Repo="https://github.com/evanw/esbuild.git"},
    @{ID="P54"; Name="prettier"; Repo="https://github.com/prettier/prettier.git"},
    @{ID="P56"; Name="puppeteer-core"; Repo="https://github.com/puppeteer/puppeteer.git"},
    @{ID="P59"; Name="playwright-core"; Repo="https://github.com/microsoft/playwright.git"},
    @{ID="P67"; Name="reduxjs-toolkit"; Repo="https://github.com/reduxjs/redux-toolkit.git"},
    @{ID="P70"; Name="chart.js"; Repo="https://github.com/chartjs/Chart.js.git"},
    @{ID="P74"; Name="stripe"; Repo="https://github.com/stripe/stripe-node.git"},
    @{ID="P76"; Name="sass"; Repo="https://github.com/sass/dart-sass.git"},
    @{ID="P77"; Name="google-cloud-firestore"; Repo="https://github.com/googleapis/nodejs-firestore.git"},
    @{ID="P78"; Name="webpack"; Repo="https://github.com/webpack/webpack.git"},
    @{ID="P79"; Name="highlight.js"; Repo="https://github.com/highlightjs/highlight.js.git"},
    @{ID="P80"; Name="sentry-core"; Repo="https://github.com/getsentry/sentry-javascript.git"},
    @{ID="P83"; Name="fp-ts"; Repo="https://github.com/gcanti/fp-ts.git"},
    @{ID="P84"; Name="html-minifier-terser"; Repo="https://github.com/terser/html-minifier-terser.git"},
    @{ID="P85"; Name="msw"; Repo="https://github.com/mswjs/msw.git"},
    @{ID="P86"; Name="luxon"; Repo="https://github.com/moment/luxon.git"},
    @{ID="P89"; Name="rxjs"; Repo="https://github.com/ReactiveX/rxjs.git"},
    @{ID="P90"; Name="faker-js"; Repo="https://github.com/faker-js/faker.git"},
    @{ID="P92"; Name="moment"; Repo="https://github.com/moment/moment.git"},
    @{ID="P95"; Name="react-router"; Repo="https://github.com/remix-run/react-router.git"},
    @{ID="P96"; Name="zod"; Repo="https://github.com/colinhacks/zod.git"},
    @{ID="P97"; Name="playwright"; Repo="https://github.com/microsoft/playwright.git"},
    @{ID="P98"; Name="mongodb"; Repo="https://github.com/mongodb/node-mongodb-native.git"},
    @{ID="P99"; Name="aws-sdk-client-s3"; Repo="https://github.com/aws/aws-sdk-js-v3.git"}
)

$reposDir = "C:\Users\anais\OneDrive\Documentos\Github\Metrics2\repositories"
$metricsDir = "C:\Users\anais\OneDrive\Documentos\Github\Metrics2\jtmetrics-runner"

if (-not (Test-Path $metricsDir)) {
    New-Item -ItemType Directory -Path $metricsDir -Force | Out-Null
    Set-Content -Path (Join-Path $metricsDir "package.json") -Value '{"name":"jtmetrics-runner","version":"1.0.0","type":"module","dependencies":{"jtmetrics":"latest"}}'
    Push-Location $metricsDir
    npm install | Out-Null
    Pop-Location
}

foreach ($p in $projects) {
    $repoPath = Join-Path $reposDir "$($p.ID)-$($p.Name)"
    Write-Host "[$($p.ID)] $($p.Name)"
    
    if (Test-Path $repoPath) {
        Write-Host "  SKIP: Already cloned"
        continue
    }
    
    New-Item -ItemType Directory -Path $repoPath -Force | Out-Null
    git clone --depth 1 $p.Repo $repoPath 2>&1 | Out-Null
    
    if (Test-Path $repoPath) {
        Write-Host "  OK"
    } else {
        Write-Host "  FAILED"
    }
}