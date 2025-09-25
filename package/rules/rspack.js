/* eslint global-require: 0 */
/* eslint no-console: 0 */

const { moduleExists } = require("../utils/helpers")

console.log("[Shakapacker] Loading Rspack rules configuration...")

const rules = []

// Use Rspack's built-in SWC loader for JavaScript files
console.log("[Shakapacker] Adding JavaScript rule with builtin:swc-loader")
rules.push({
  test: /\.(js|jsx|mjs)$/,
  exclude: /node_modules/,
  type: "javascript/auto",
  use: [
    {
      loader: "builtin:swc-loader",
      options: {
        jsc: {
          parser: {
            syntax: "ecmascript",
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

// Use Rspack's built-in SWC loader for TypeScript files
console.log("[Shakapacker] Adding TypeScript rule with builtin:swc-loader")
rules.push({
  test: /\.(ts|tsx)$/,
  exclude: /node_modules/,
  type: "javascript/auto",
  use: [
    {
      loader: "builtin:swc-loader",
      options: {
        jsc: {
          parser: {
            syntax: "typescript",
            tsx: true
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
console.log("[Shakapacker] Checking for CSS loader...")
if (moduleExists("css-loader")) {
  console.log(
    "[Shakapacker] css-loader found, loading CSS rule configuration..."
  )
  const css = require("./css")
  if (css) {
    console.log("[Shakapacker] Successfully added CSS rule")
    rules.push(css)
  } else {
    console.log(
      "[Shakapacker] WARNING: css-loader found but rule configuration returned null"
    )
  }
} else {
  console.log(
    "[Shakapacker] INFO: Skipping CSS support - css-loader not installed"
  )
}

// Sass rules
console.log("[Shakapacker] Checking for Sass loader...")
if (moduleExists("sass") && moduleExists("sass-loader")) {
  console.log(
    "[Shakapacker] sass and sass-loader found, loading Sass rule configuration..."
  )
  const sass = require("./sass")
  if (sass) {
    console.log("[Shakapacker] Successfully added Sass rule")
    rules.push(sass)
  } else {
    console.log(
      "[Shakapacker] WARNING: sass and sass-loader found but rule configuration returned null"
    )
  }
} else if (!moduleExists("sass")) {
  console.log("[Shakapacker] INFO: Skipping Sass support - sass not installed")
} else if (!moduleExists("sass-loader")) {
  console.log(
    "[Shakapacker] INFO: Skipping Sass support - sass-loader not installed"
  )
}

// Less rules
console.log("[Shakapacker] Checking for Less loader...")
if (moduleExists("less") && moduleExists("less-loader")) {
  console.log(
    "[Shakapacker] less and less-loader found, loading Less rule configuration..."
  )
  const less = require("./less")
  if (less) {
    console.log("[Shakapacker] Successfully added Less rule")
    rules.push(less)
  } else {
    console.log(
      "[Shakapacker] WARNING: less and less-loader found but rule configuration returned null"
    )
  }
} else if (!moduleExists("less")) {
  console.log("[Shakapacker] INFO: Skipping Less support - less not installed")
} else if (!moduleExists("less-loader")) {
  console.log(
    "[Shakapacker] INFO: Skipping Less support - less-loader not installed"
  )
}

// Stylus rules
console.log("[Shakapacker] Checking for Stylus loader...")
if (moduleExists("stylus") && moduleExists("stylus-loader")) {
  console.log(
    "[Shakapacker] stylus and stylus-loader found, loading Stylus rule configuration..."
  )
  const stylus = require("./stylus")
  if (stylus) {
    console.log("[Shakapacker] Successfully added Stylus rule")
    rules.push(stylus)
  } else {
    console.log(
      "[Shakapacker] WARNING: stylus and stylus-loader found but rule configuration returned null"
    )
  }
} else if (!moduleExists("stylus")) {
  console.log(
    "[Shakapacker] INFO: Skipping Stylus support - stylus not installed"
  )
} else if (!moduleExists("stylus-loader")) {
  console.log(
    "[Shakapacker] INFO: Skipping Stylus support - stylus-loader not installed"
  )
}

// ERB template support
console.log("[Shakapacker] Checking for ERB template support...")
const erb = require("./erb")

if (erb) {
  console.log("[Shakapacker] Successfully added ERB rule")
  rules.push(erb)
} else {
  console.log(
    "[Shakapacker] INFO: Skipping ERB support - rails-erb-loader not installed"
  )
}

// File/asset handling using Rspack's built-in asset modules
console.log("[Shakapacker] Adding file/asset handling rule...")
const file = require("./file")

if (file) {
  console.log("[Shakapacker] Successfully added file/asset rule")
  rules.push(file)
} else {
  console.log("[Shakapacker] WARNING: file rule configuration returned null")
}

// Raw file loading
console.log("[Shakapacker] Adding raw file loading rule...")
const raw = require("./raw")

if (raw) {
  console.log("[Shakapacker] Successfully added raw file rule")
  rules.push(raw)
} else {
  console.log("[Shakapacker] WARNING: raw rule configuration returned null")
}

console.log(
  `[Shakapacker] Rspack rules configuration complete. Total rules: ${rules.length}`
)
module.exports = rules
