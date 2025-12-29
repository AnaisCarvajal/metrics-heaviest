/**
 * Script para DEMOSTRAR QUE EL BUG CAUSA PROBLEMAS REALES
 * Sin reset() en calculateMetrics(), los errores se acumulan entre análisis
 */

import { logger } from './jtmetrics/src/logger/logger.js'

console.log('\n' + '='.repeat(70))
console.log('DEMOSTRANDO EL BUG REAL: LOGGER SIN RESET() EN calculateMetrics()')
console.log('='.repeat(70))

console.log('\n🔍 ESCENARIO: Ejecutar calculateMetrics() dos veces en la misma sesión')
console.log('   (Como haría un CI/CD o un test suite)\n')

// Simulamos lo que sucede INTERNAMENTE en calculateMetrics
// PRIMERO ANÁLISIS
console.log('📊 ANÁLISIS 1: Proyecto A')
logger.logFileError('Error en fileA.js: sintaxis inválida')
logger.logParseError('Parse error en componentA.ts')
console.log('   Errores después del análisis 1:', logger.getFileErrors().length, 'file errors')
console.log('   ➜', logger.getFileErrors())

// SEGUNDO ANÁLISIS - SIN RESET (COMO ESTÁ AHORA)
console.log('\n📊 ANÁLISIS 2: Proyecto B (MISMO LOGGER INSTANCE)')
logger.logFileError('Error en fileB.js: import faltante')
console.log('\n❌ PROBLEMA DETECTADO:')
console.log('   Errores después del análisis 2:', logger.getFileErrors().length, 'file errors')
console.log('   ESPERADO: 1 error (solo de Proyecto B)')
console.log('   ACTUAL:  ', logger.getFileErrors().length, 'errores (incluye de Proyecto A)')
console.log('   ➜', logger.getFileErrors())

// Mostrar el impacto
console.log('\n💥 IMPACTO DEL BUG:')
console.log('   1. El usuario ve errores del PROYECTO A en los resultados del PROYECTO B')
console.log('   2. Los reportes tienen datos FALSOS y CONTAMINADOS')
console.log('   3. En CI/CD con muchos tests, errores se acumulan exponencialmente')
console.log('   4. IMPOSIBLE debuggear qué errores son de dónde')

// Ahora mostramos la solución
console.log('\n✅ SOLUCIÓN: Llamar logger.reset() al inicio de calculateMetrics()')
logger.reset()
console.log('   logger.reset() ← Limpia TODO')
logger.logFileError('Error en fileC.js: tipo incorrecto')
console.log('\n   Errores después del reset:', logger.getFileErrors().length, 'file errors')
console.log('   CORRECTO: Solo 1 error (del análisis actual)')
console.log('   ➜', logger.getFileErrors())

console.log('\n' + '='.repeat(70))
console.log('CONCLUSIÓN: Sin reset(), logger es un SINGLETON CONTAMINADO')
console.log('='.repeat(70) + '\n')
