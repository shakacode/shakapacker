module.exports = {
  root: true, // Prevent ESLint from looking in parent directories
  extends: ["airbnb", "plugin:prettier/recommended"],
  rules: {
    // Webpack handles module resolution, not ESLint
    "import/no-unresolved": "off",
    // Allow importing devDependencies in config/test files
    "import/no-extraneous-dependencies": "off",
    // TypeScript handles extensions, not needed for JS imports
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
        // TypeScript compiler handles module resolution
        "import/no-unresolved": "off",
        // Allow importing devDependencies in TypeScript files
        "import/no-extraneous-dependencies": "off",
        // TypeScript handles file extensions via moduleResolution
        "import/extensions": "off",
        // Disable base rule in favor of TypeScript version
        "no-use-before-define": "off",
        "@typescript-eslint/no-use-before-define": ["error"],
        // Allow unused vars if they start with underscore (convention for ignored params)
        "@typescript-eslint/no-unused-vars": [
          "error",
          { argsIgnorePattern: "^_" }
        ],
        // Strict: no 'any' types allowed - use 'unknown' or specific types instead
        "@typescript-eslint/no-explicit-any": "error",
        // Allow implicit return types - TypeScript can infer them
        "@typescript-eslint/explicit-module-boundary-types": "off"
      }
    }
  ]
}
