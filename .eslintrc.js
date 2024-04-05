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
      extends: ["plugin:jest/recommended", "plugin:jest/style"],
      rules: {
        "global-require": "off"
      }
    }
  ]
}
