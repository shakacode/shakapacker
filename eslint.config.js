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

  // TypeScript files
  {
    files: ["**/*.ts", "**/*.tsx"],
    languageOptions: {
      parser: typescriptParser,
      parserOptions: {
        // Enables type-aware linting for better type safety
        // Note: This can slow down linting on large codebases
        // Consider using --cache flag with ESLint if performance degrades
        project: "./tsconfig.eslint.json",
        tsconfigRootDir: __dirname
      }
    },
    plugins: {
      "@typescript-eslint": typescriptPlugin
    },
    rules: {
      ...typescriptPlugin.configs.recommended.rules,
      ...typescriptPlugin.configs["recommended-requiring-type-checking"].rules,
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
  },

  // Prettier config must be last to override other configs
  prettierConfig
]
