import { calculateMetrics } from './jtmetrics/src/index.js'
import { writeFileSync, mkdirSync, statSync } from 'fs'
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

const startTime = Date.now()

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

const endTime = Date.now()
const executionTimeMs = endTime - startTime
const executionTimeSec = (executionTimeMs / 1000).toFixed(2)

// Calculate total size of all files
let totalSizeBytes = 0
const fileBreakdown = {}
for (const [metricName] of Object.entries(results)) {
  const metricFile = resolve(resultsDir, `${metricName}.json`)
  const stats = statSync(metricFile)
  fileBreakdown[metricName] = {
    bytes: stats.size,
    KB: (stats.size / 1024).toFixed(2),
    MB: (stats.size / (1024 * 1024)).toFixed(4)
  }
  totalSizeBytes += stats.size
}

const totalSizeMB = (totalSizeBytes / (1024 * 1024)).toFixed(4)
const totalSizeKB = (totalSizeBytes / 1024).toFixed(2)

// Save summary
const summary = {
  projectId: projectId,
  projectName: projectName,
  analyzedAt: new Date().toISOString(),
  totalFiles: results.files?.result?.length || 0,
  metricsAvailable: Object.keys(results),
  execution: {
    timeMs: executionTimeMs,
    timeSec: parseFloat(executionTimeSec)
  },
  size: {
    totalBytes: totalSizeBytes,
    totalKB: parseFloat(totalSizeKB),
    totalMB: parseFloat(totalSizeMB),
    fileBreakdown: fileBreakdown
  }
}

writeFileSync(resultsPath, JSON.stringify(summary, null, 2), 'utf-8')
console.log(`Complete - ${executionTimeSec}s, ${totalSizeMB}MB`)
