// Fast ESLint config for quick development feedback
// Skips type-aware rules that require TypeScript compilation

const baseConfig = require("./.eslintrc.js")

module.exports = {
  ...baseConfig,
  overrides: [
    ...baseConfig.overrides.filter((o) => !o.files.includes("**/*.{ts,tsx}")),
    {
      files: ["**/*.{ts,tsx}"],
      parser: "@typescript-eslint/parser",
      parserOptions: {
        // No project specified - disables type-aware linting
        ecmaVersion: 2020,
        sourceType: "module"
      },
      extends: [
        "plugin:@typescript-eslint/recommended",
        // Skip the "recommended-requiring-type-checking" preset
        "plugin:prettier/recommended"
      ],
      plugins: ["@typescript-eslint"],
      rules: {
        // Same rules as main config minus type-aware ones
        "import/no-unresolved": "off",
        "import/no-extraneous-dependencies": "off",
        "import/extensions": "off",
        "no-use-before-define": "off",
        "@typescript-eslint/no-use-before-define": ["error"],
        "@typescript-eslint/no-unused-vars": [
          "error",
          { argsIgnorePattern: "^_" }
        ],
        "@typescript-eslint/no-explicit-any": "error",
        "@typescript-eslint/explicit-module-boundary-types": "off"
      }
    }
  ]
}
