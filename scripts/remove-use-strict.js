#!/usr/bin/env node
const fs = require('fs')
const path = require('path')

// Recursively find all .js files in a directory
function findJsFiles(dir) {
  const files = []
  const items = fs.readdirSync(dir, { withFileTypes: true })

  for (const item of items) {
    const fullPath = path.join(dir, item.name)
    if (item.isDirectory()) {
      files.push(...findJsFiles(fullPath))
    } else if (item.isFile() && item.name.endsWith('.js')) {
      files.push(fullPath)
    }
  }

  return files
}

// Find all .js files in package directory
const files = findJsFiles('package')

files.forEach(file => {
  let content = fs.readFileSync(file, 'utf8')

  // Remove "use strict"; or "use strict" from the beginning of the file
  content = content.replace(/^["']use strict["'];?\s*\n?/, '')

  fs.writeFileSync(file, content, 'utf8')
})

console.log(`Removed "use strict" from ${files.length} files`)