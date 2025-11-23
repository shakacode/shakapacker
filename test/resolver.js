const { resolve } = require("path")

const mapping = {
  "css-loader": "this path was mocked",
  "sass-loader/package.json": "../../__mocks__/sass-loader/package.json",
  "nonexistent/package.json": "../../__mocks__/nonexistent/package.json"
}

function resolver(module, options) {
  // Handle .js imports that should resolve to .ts files for rspack
  if (module.endsWith("/plugins/rspack.js")) {
    return resolve(__dirname, "../package/plugins/rspack.ts")
  }
  if (module.endsWith("/rules/rspack.js")) {
    return resolve(__dirname, "../package/rules/rspack.ts")
  }
  if (module.endsWith("/optimization/rspack.js")) {
    return resolve(__dirname, "../package/optimization/rspack.ts")
  }

  // If the path corresponds to a key in the mapping object, returns the fakely resolved path
  // otherwise it calls the Jest's default resolver
  return mapping[module] || options.defaultResolver(module, options)
}

module.exports = resolver
