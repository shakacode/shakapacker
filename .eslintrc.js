module.exports = {
  extends: ["airbnb", "plugin:prettier/recommended"],
  rules: {
    "import/no-unresolved": "off",
    "import/no-extraneous-dependencies": "off",
    "import/extensions": "off",
    indent: ["error", 2]
  },
  env: {
    browser: true,
    node: true
  },
  overrides: [
    {
      files: ["test/**"],
      // todo: these should be sourced from eslint-plugin-jest
      env: { jest: true },
      rules: {
        "global-require": "off"
      }
    }
  ]
}
