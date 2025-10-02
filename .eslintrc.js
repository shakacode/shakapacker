module.exports = {
  root: true,
  extends: ["airbnb", "plugin:prettier/recommended"],
  rules: {
    "import/no-unresolved": "off",
    "import/no-extraneous-dependencies": "off",
    "import/extensions": "off",
    indent: ["error", 2]
  },
  settings: {
    react: {
      // Suppress "react package not installed" warning
      // This project doesn't use React but airbnb config requires react-plugin
      version: "999.999.999"
    }
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
    },
    {
      files: ["**/*.ts"],
      parser: "@typescript-eslint/parser",
      parserOptions: {
        project: "./tsconfig.json"
      },
      extends: [
        "plugin:@typescript-eslint/recommended",
        "plugin:@typescript-eslint/recommended-requiring-type-checking",
        "plugin:prettier/recommended"
      ],
      plugins: ["@typescript-eslint"],
      rules: {
        "import/no-unresolved": "off",
        "import/no-extraneous-dependencies": "off",
        "import/extensions": "off",
        indent: "off",
        "@typescript-eslint/indent": ["error", 2],
        "@typescript-eslint/no-unused-vars": [
          "error",
          { argsIgnorePattern: "^_" }
        ],
        "@typescript-eslint/no-explicit-any": "warn",
        "@typescript-eslint/explicit-module-boundary-types": "off",
        "@typescript-eslint/no-var-requires": "off",
        "@typescript-eslint/ban-ts-comment": "off",
        "no-use-before-define": "off",
        "@typescript-eslint/no-use-before-define": ["error"]
      }
    }
  ]
}
