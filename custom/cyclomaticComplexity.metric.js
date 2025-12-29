const state = {
  name: 'Cyclomatic Complexity',
  description: 'Calculates McCabe Cyclomatic Complexity for each function and class method',
  result: {},
  id: 'cyclomatic-complexity',
  dependencies: ['functions-per-file', 'classes-per-file'],
  status: false
}

/**
 * Calculate cyclomatic complexity for a given path
 * Complexity = 1 (base) + number of decision points
 * Iterative traversal to prevent stack overflow - O(n)
 */
function calculateComplexity (path) {
  let complexity = 1
  
  // Use iterative stack-based traversal
  const nodesToVisit = [path.node]
  const nodeTypeCounters = {
    IfStatement: 0,
    ConditionalExpression: 0,
    ForStatement: 0,
    ForInStatement: 0,
    ForOfStatement: 0,
    WhileStatement: 0,
    DoWhileStatement: 0,
    SwitchCase: 0,
    LogicalExpression: 0,
    CatchClause: 0
  }
  
  while (nodesToVisit.length > 0) {
    const node = nodesToVisit.pop()
    if (!node || typeof node !== 'object') continue
    
    // Count decision points - O(1) per node
    if (node.type === 'IfStatement') complexity++
    else if (node.type === 'ConditionalExpression') complexity++
    else if (node.type === 'ForStatement') complexity++
    else if (node.type === 'ForInStatement') complexity++
    else if (node.type === 'ForOfStatement') complexity++
    else if (node.type === 'WhileStatement') complexity++
    else if (node.type === 'DoWhileStatement') complexity++
    else if (node.type === 'SwitchCase' && node.test !== null) complexity++
    else if (node.type === 'LogicalExpression' && (node.operator === '&&' || node.operator === '||')) complexity++
    else if (node.type === 'CatchClause') complexity++
    
    // Add children to stack
    for (const key in node) {
      if (key === 'parentPath' || key === 'parent' || key === 'loc') continue
      
      const child = node[key]
      if (Array.isArray(child)) {
        for (let i = child.length - 1; i >= 0; i--) {
          if (child[i]) nodesToVisit.push(child[i])
        }
      } else if (child && typeof child === 'object') {
        nodesToVisit.push(child)
      }
    }
  }
  
  return complexity
}

const visitors = {
  Program (path) {
    state.currentFile = path.node.filePath
    
    if (!state.result[state.currentFile]) {
      state.result[state.currentFile] = {
        functions: {},
        classes: {}
      }
    }
  },

  // Function declarations
  FunctionDeclaration (path) {
    if (!path.node.id || !path.node.id.name) return
    
    const functionName = path.node.id.name
    const complexity = calculateComplexity(path)
    
    if (!state.result[state.currentFile].functions[functionName]) {
      state.result[state.currentFile].functions[functionName] = {}
    }
    
    state.result[state.currentFile].functions[functionName].complexity = complexity
  },

  // Function expressions
  FunctionExpression (path) {
    let functionName = ''
    
    if (path.parentPath.node.type === 'VariableDeclarator' && path.parentPath.node.id.name) {
      functionName = path.parentPath.node.id.name
    } else return
    
    const complexity = calculateComplexity(path)
    
    if (!state.result[state.currentFile].functions[functionName]) {
      state.result[state.currentFile].functions[functionName] = {}
    }
    
    state.result[state.currentFile].functions[functionName].complexity = complexity
  },

  // Arrow functions
  ArrowFunctionExpression (path) {
    if (!path.parentPath.node.id || !path.parentPath.node.id.name) return
    
    const functionName = path.parentPath.node.id.name
    const complexity = calculateComplexity(path)
    
    if (!state.result[state.currentFile].functions[functionName]) {
      state.result[state.currentFile].functions[functionName] = {}
    }
    
    state.result[state.currentFile].functions[functionName].complexity = complexity
  },

  // Class methods
  ClassDeclaration (path) {
    const node = path.node
    
    if (!node.id || !node.id.name) return
    
    const className = node.id.name
    
    if (!state.result[state.currentFile].classes[className]) {
      state.result[state.currentFile].classes[className] = {}
    }
    
    path.traverse({
      ClassMethod (methodPath) {
        const methodName = methodPath.node.key.name || (methodPath.node.kind === 'constructor' ? '_constructor' : 'anonymous')
        const complexity = calculateComplexity(methodPath)
        
        if (!state.result[state.currentFile].classes[className][methodName]) {
          state.result[state.currentFile].classes[className][methodName] = {}
        }
        
        state.result[state.currentFile].classes[className][methodName].complexity = complexity
      }
    })
  },

  // Class expressions
  ClassExpression (path) {
    const parentPath = path.parentPath
    
    if (parentPath.node.type === 'VariableDeclarator' && parentPath.node.id && parentPath.node.id.name) {
      const className = parentPath.node.id.name
      
      if (!state.result[state.currentFile].classes[className]) {
        state.result[state.currentFile].classes[className] = {}
      }
      
      path.traverse({
        ClassMethod (methodPath) {
          const methodName = methodPath.node.key.name || (methodPath.node.kind === 'constructor' ? '_constructor' : 'anonymous')
          const complexity = calculateComplexity(methodPath)
          
          if (!state.result[state.currentFile].classes[className][methodName]) {
            state.result[state.currentFile].classes[className][methodName] = {}
          }
          
          state.result[state.currentFile].classes[className][methodName].complexity = complexity
        }
      })
    }
  }
}

function postProcessing (state) {
  delete state.currentFile
  delete state.dependencies
  state.status = true
}

export { state, visitors, postProcessing }
