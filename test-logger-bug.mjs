/**
 * Script to demonstrate the logger accumulation bug and the fix
 * 
 * ANTES del fix: errores se acumulan entre ejecuciones
 * DESPUES del fix: logger.reset() limpia los errores
 */

import { logger } from './jtmetrics/src/logger/logger.js'

console.log('='.repeat(60))
console.log('DEMOSTRANDO BUG DEL LOGGER - ACUMULACION DE ERRORES')
console.log('='.repeat(60))

// Simulamos primera ejecución de análisis
console.log('\n📊 PRIMERA EJECUCIÓN:')
logger.logFileError('Error: No se encontró archivo main.js')
logger.logMetricError('Error: Métrica X falló')
console.log('Errores de archivo:', logger.getFileErrors())
console.log('Errores de métrica:', logger.getMetricErrors())

// SIN RESET - Los errores se acumulan
console.log('\n❌ SEGUNDA EJECUCIÓN (SIN RESET - BUG):')
logger.logFileError('Error: No se encontró archivo app.js')
console.log('Errores de archivo:', logger.getFileErrors())
console.log('⚠️  PROBLEMA: El error anterior aún está aquí!')
console.log(`   Total: ${logger.getFileErrors().length} errores (debería ser 1)`)

// Ahora con RESET - Bug solucionado
console.log('\n✅ TERCERA EJECUCIÓN (CON RESET - SOLUCION):')
logger.reset()
console.log('✨ Logger reseteado')
logger.logFileError('Error: No se encontró archivo utils.js')
console.log('Errores de archivo:', logger.getFileErrors())
console.log('✓ CORRECTO: Solo el error nuevo')
console.log(`   Total: ${logger.getFileErrors().length} errores (correcto)`)

console.log('\n' + '='.repeat(60))
console.log('CÓMO VERIFICAR EL FIX EN CODIGO REAL:')
console.log('='.repeat(60))
console.log(`
1. Ve a: src/index.js línea 40
2. Verás que calculateMetrics() llama logger.reset()
3. Esto garantiza que cada análisis comienza con un logger limpio
4. 
5. Para probar:
   npm test -- logger.test.js --testNamePattern="reset"
`)

console.log('\n' + '='.repeat(60))
