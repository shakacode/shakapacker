/* eslint global-require: 0 */

const { canProcess, moduleExists } = require("../../utils/helpers")

const rules = []

// Use Rspack's built-in SWC loader for JS/TS/JSX/TSX files
rules.push({
  test: /\.(js|jsx|ts|tsx|mjs)$/,
  exclude: /node_modules/,
  type: "javascript/auto",
  use: [
    {
      loader: "builtin:swc-loader",
      options: {
        jsc: {
          parser: {
            syntax: "typescript",
            tsx: true,
            jsx: true
          },
          transform: {
            react: {
              runtime: "automatic"
            }
          }
        }
      }
    }
  ]
})

// CSS rules using Rspack's built-in CSS handling
if (moduleExists("css-loader")) {
  const css = require("./css")
  rules.push(css)
}

// Sass rules
if (moduleExists("sass") && moduleExists("sass-loader")) {
  const sass = require("./sass")
  rules.push(sass)
}

// Less rules  
if (moduleExists("less") && moduleExists("less-loader")) {
  const less = require("./less")
  rules.push(less)
}

// Stylus rules
if (moduleExists("stylus") && moduleExists("stylus-loader")) {
  const stylus = require("./stylus")
  rules.push(stylus)
}

// ERB template support
const erb = require("./erb")
rules.push(erb)

// File/asset handling using Rspack's built-in asset modules
const file = require("./file")
rules.push(file)

// Raw file loading
const raw = require("./raw")
rules.push(raw)

module.exports = rules