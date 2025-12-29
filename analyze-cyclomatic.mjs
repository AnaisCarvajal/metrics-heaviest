import { calculateMetrics } from './jtmetrics-runner/node_modules/jtmetrics/src/index.js'
import { writeFileSync, mkdirSync, statSync } from 'fs'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = dirname(__filename)

const projectId = process.argv[2]
const projectName = process.argv[3]

if (!projectId || !projectName) {
  console.error('Usage: node analyze-cyclomatic.mjs <projectId> <projectName>')
  process.exit(1)
}

const repoPath = resolve(__dirname, 'repositories', `${projectId}-${projectName}`)
const customResultsDir = resolve(__dirname, 'custom-results', `${projectId}-${projectName}`)
const customMetricFile = resolve(customResultsDir, 'cyclomatic-complexity.json')

mkdirSync(customResultsDir, { recursive: true })

console.log(`Analyzing ${projectId}-${projectName} (cyclomatic complexity only)...`)

const startTime = Date.now()

try {
  const results = await calculateMetrics({
    codePath: repoPath,
    useDefaultMetrics: false,
    customMetricsPath: resolve(__dirname, 'custom')
  })

  if (results && results['cyclomatic-complexity']) {
    const complexityData = results['cyclomatic-complexity']
    
    try {
      writeFileSync(customMetricFile, JSON.stringify(complexityData, null, 2), 'utf-8')
    } catch (writeError) {
      writeFileSync(customMetricFile, JSON.stringify(complexityData), 'utf-8')
    }

    const endTime = Date.now()
    const executionTimeMs = endTime - startTime
    const executionTimeSec = (executionTimeMs / 1000).toFixed(2)

    const fileStats = statSync(customMetricFile)
    const fileSizeMB = (fileStats.size / (1024 * 1024)).toFixed(4)

    const summary = {
      projectId: projectId,
      projectName: projectName,
      metric: 'cyclomatic-complexity',
      analyzedAt: new Date().toISOString(),
      execution: {
        timeMs: executionTimeMs,
        timeSec: parseFloat(executionTimeSec)
      },
      size: {
        bytes: fileStats.size,
        KB: (fileStats.size / 1024).toFixed(2),
        MB: parseFloat(fileSizeMB)
      }
    }

    console.log(`Complete - ${executionTimeSec}s, ${fileSizeMB}MB`)
    console.log(JSON.stringify(summary))
  } else {
    throw new Error('Cyclomatic complexity metric not found in results')
  }
} catch (error) {
  console.error(`Analysis failed: ${error.message}`)
  process.exit(1)
}
