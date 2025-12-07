import { calculateMetrics } from './jtmetrics-runner/node_modules/jtmetrics/src/index.js'
import { writeFileSync, mkdirSync } from 'fs'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = dirname(__filename)

const projectId = process.argv[2]
const projectName = process.argv[3]

if (!projectId || !projectName) {
  console.error('Usage: node analyze.mjs <projectId> <projectName>')
  process.exit(1)
}

const repoPath = resolve(__dirname, 'repositories', `${projectId}-${projectName}`)
const resultsDir = resolve(__dirname, 'results', `${projectId}-${projectName}`)
const resultsPath = resolve(resultsDir, 'results.json')

mkdirSync(resultsDir, { recursive: true })

console.log(`Analyzing ${projectId}-${projectName}...`)

const results = await calculateMetrics({
  codePath: repoPath,
  useDefaultMetrics: true
})

// Save each metric in separate files to avoid memory limits
for (const [metricName, metricData] of Object.entries(results)) {
  const metricFile = resolve(resultsDir, `${metricName}.json`)
  try {
    writeFileSync(metricFile, JSON.stringify(metricData, null, 2), 'utf-8')
  } catch (error) {
    // If formatted fails, save unformatted
    writeFileSync(metricFile, JSON.stringify(metricData), 'utf-8')
  }
}

// Save summary
const summary = {
  projectId: projectId,
  projectName: projectName,
  analyzedAt: new Date().toISOString(),
  totalFiles: results.files?.result?.length || 0,
  metricsAvailable: Object.keys(results)
}

writeFileSync(resultsPath, JSON.stringify(summary, null, 2), 'utf-8')
console.log('Complete')
