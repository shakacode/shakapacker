// Fast ESLint config for quick development feedback
// Skips type-aware rules that require TypeScript compilation

const { FlatCompat } = require("@eslint/eslintrc")
const js = require("@eslint/js")
const typescriptParser = require("@typescript-eslint/parser")
const typescriptPlugin = require("@typescript-eslint/eslint-plugin")
const jestPlugin = require("eslint-plugin-jest")
const prettierConfig = require("eslint-config-prettier")

const compat = new FlatCompat({
  baseDirectory: __dirname,
  recommendedConfig: js.configs.recommended
})

module.exports = [
  // Global ignores (replaces .eslintignore)
  {
    ignores: [
      "lib/**",
      "**/node_modules/**",
      "vendor/**",
      "spec/**",
      "package/**" // TODO: Remove after PR #644 merges (lints package/ TS source files)
    ]
  },

  // Base config for all JS files
  ...compat.extends("airbnb"),
  {
    languageOptions: {
      ecmaVersion: 2020,
      sourceType: "module",
      globals: {
        // Browser globals
        window: "readonly",
        document: "readonly",
        navigator: "readonly",
        console: "readonly",
        // Node globals
        process: "readonly",
        __dirname: "readonly",
        __filename: "readonly",
        module: "readonly",
        require: "readonly",
        exports: "readonly",
        global: "readonly",
        Buffer: "readonly"
      }
    },
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
    }
  },

  // Jest test files
  {
    files: ["test/**"],
    plugins: {
      jest: jestPlugin
    },
    languageOptions: {
      globals: {
        ...jestPlugin.environments.globals.globals
      }
    },
    rules: {
      ...jestPlugin.configs.recommended.rules,
      ...jestPlugin.configs.style.rules,
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

  // TypeScript files - fast mode without type-aware linting
  {
    files: ["**/*.ts", "**/*.tsx"],
    languageOptions: {
      parser: typescriptParser,
      parserOptions: {
        // No project specified - disables type-aware linting
        ecmaVersion: 2020,
        sourceType: "module"
      }
    },
    plugins: {
      "@typescript-eslint": typescriptPlugin
    },
    rules: {
      ...typescriptPlugin.configs.recommended.rules,
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
  },

  // Prettier config must be last to override other configs
  prettierConfig
]
