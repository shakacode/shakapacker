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
      "lib/**", // Ruby files, not JavaScript
      "**/node_modules/**", // Third-party dependencies
      "vendor/**", // Vendored dependencies
      "spec/**", // Ruby specs, not JavaScript
      "package/**/*.js", // Generated/compiled JavaScript from TypeScript
      "package/**/*.d.ts", // Generated TypeScript declaration files
      // Temporarily ignore TypeScript files until technical debt is resolved
      // See ESLINT_TECHNICAL_DEBT.md for tracking
      // TODO: Remove this once ESLint issues are fixed (tracked in #723)
      "package/**/*.ts"
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
      indent: ["error", 2],
      // Allow for...of loops - modern JS syntax, won't pollute client code
      "no-restricted-syntax": "off",
      // Allow console statements - used for debugging/logging throughout
      "no-console": "off"
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
      "@typescript-eslint/explicit-module-boundary-types": "off",
      // Disable no-undef for TypeScript - TypeScript compiler handles this
      // This prevents false positives for ambient types like NodeJS.ProcessEnv
      "no-undef": "off"
    }
  },

  // Temporary overrides for files with remaining errors
  // See ESLINT_TECHNICAL_DEBT.md for detailed documentation
  //
  // These overrides suppress ~172 errors that require either:
  // 1. Major type refactoring (any/unsafe-* rules)
  // 2. Potential breaking changes (module system)
  // 3. Significant code restructuring
  //
  // GitHub Issues tracking this technical debt:
  // - #707: TypeScript: Refactor configExporter module for type safety
  // - #708: Module System: Modernize to ES6 modules with codemod
  // - #709: Code Style: Fix remaining ESLint style issues
  {
    // Consolidated override for package/config.ts and package/babel/preset.ts
    // Combines rules from both previous override blocks to avoid duplication
    files: ["package/babel/preset.ts", "package/config.ts"],
    rules: {
      // From first override block
      "@typescript-eslint/no-require-imports": "off",
      "@typescript-eslint/no-unused-vars": "off",
      "@typescript-eslint/no-unsafe-call": "off",
      "import/order": "off",
      "import/newline-after-import": "off",
      "import/first": "off",
      // Additional rules that were in the second override for config.ts
      "@typescript-eslint/no-unsafe-assignment": "off",
      "@typescript-eslint/no-unsafe-member-access": "off",
      "@typescript-eslint/no-unsafe-argument": "off",
      "@typescript-eslint/no-explicit-any": "off",
      "no-useless-escape": "off",
      "no-continue": "off",
      "no-nested-ternary": "off"
    }
  },
  {
    files: ["package/configExporter/**/*.ts"],
    rules: {
      "@typescript-eslint/no-explicit-any": "off",
      "@typescript-eslint/no-unsafe-assignment": "off",
      "@typescript-eslint/no-unsafe-member-access": "off",
      "@typescript-eslint/no-unsafe-call": "off",
      "@typescript-eslint/no-unsafe-return": "off",
      "@typescript-eslint/no-unsafe-argument": "off",
      "@typescript-eslint/no-unsafe-function-type": "off",
      "@typescript-eslint/no-unused-vars": "off",
      "@typescript-eslint/require-await": "off",
      "no-param-reassign": "off",
      "no-await-in-loop": "off",
      "no-nested-ternary": "off",
      "import/prefer-default-export": "off",
      "global-require": "off",
      "no-underscore-dangle": "off",
      "class-methods-use-this": "off"
    }
  },
  {
    // Remaining utils files (removed package/config.ts from this block)
    files: [
      "package/utils/inliningCss.ts",
      "package/utils/errorCodes.ts",
      "package/utils/errorHelpers.ts",
      "package/utils/pathValidation.ts"
    ],
    rules: {
      "@typescript-eslint/no-unsafe-assignment": "off",
      "@typescript-eslint/no-unsafe-member-access": "off",
      "@typescript-eslint/no-unsafe-argument": "off",
      "@typescript-eslint/no-explicit-any": "off",
      "no-useless-escape": "off",
      "no-continue": "off",
      "no-nested-ternary": "off"
    }
  },
  {
    files: ["package/plugins/**/*.ts", "package/optimization/**/*.ts"],
    rules: {
      "@typescript-eslint/no-unsafe-assignment": "off",
      "@typescript-eslint/no-unsafe-call": "off",
      "@typescript-eslint/no-redundant-type-constituents": "off",
      "import/prefer-default-export": "off"
    }
  },
  {
    files: [
      "package/environments/**/*.ts",
      "package/index.ts",
      "package/rspack/index.ts",
      "package/rules/**/*.ts",
      "package/swc/index.ts",
      "package/esbuild/index.ts",
      "package/dev_server.ts",
      "package/env.ts"
    ],
    rules: {
      "@typescript-eslint/no-unsafe-assignment": "off",
      "@typescript-eslint/no-unsafe-call": "off",
      "@typescript-eslint/no-unsafe-return": "off",
      "@typescript-eslint/no-redundant-type-constituents": "off",
      "@typescript-eslint/no-unused-vars": "off",
      "@typescript-eslint/no-unsafe-function-type": "off",
      "import/prefer-default-export": "off",
      "no-underscore-dangle": "off"
    }
  },

  // Prettier config must be last to override other configs
  prettierConfig
]
