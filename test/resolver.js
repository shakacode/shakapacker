const mapping = {
  "css-loader": "this path was mocked",
  "sass-loader/package.json": "../../__mocks__/sass-loader/package.json",
  "nonexistent/package.json": "../../__mocks__/nonexistent/package.json"
}

function resolver(module, options) {
  // If the path corresponds to a key in the mapping object, returns the fakely resolved path
  // otherwise it calls the Jest's default resolver
  return mapping[module] || options.defaultResolver(module, options)
}

module.exports = resolver
