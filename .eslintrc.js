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
        "global-require": "off",
        "jest/prefer-called-with": "error",
        "jest/no-conditional-in-test": "error",
        "jest/no-test-return-statement": "error",
        "jest/prefer-expect-resolves": "error",
        "jest/require-to-throw-message": "error",
        "jest/require-top-level-describe": "error",
        "jest/prefer-hooks-on-top": "error",
        "jest/prefer-lowercase-title": [
          "error",
          { ignoreTopLevelDescribe: true }
        ],
        "jest/prefer-spy-on": "error",
        "jest/prefer-strict-equal": "error",
        "jest/prefer-todo": "error"
      }
    }
  ]
}
