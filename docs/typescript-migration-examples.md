# TypeScript Migration Examples

This guide provides practical examples for migrating your Shakapacker configuration from JavaScript to TypeScript.

## Table of Contents
- [Basic Migration](#basic-migration)
- [Advanced Configurations](#advanced-configurations)
- [IDE Support](#ide-support)
- [Common Patterns](#common-patterns)
- [Troubleshooting](#troubleshooting)

## Basic Migration

### Step 1: Simple JavaScript to TypeScript

**Before (webpack.config.js):**
```javascript
const { generateWebpackConfig } = require('shakapacker')

module.exports = generateWebpackConfig({
  entry: {
    application: './app/javascript/application.js'
  },
  resolve: {
    extensions: ['.css', '.scss']
  }
})
```

**After (webpack.config.ts):**
```typescript
import { generateWebpackConfig } from 'shakapacker'
import type { Configuration } from 'webpack'

const customConfig: Configuration = {
  entry: {
    application: './app/javascript/application.ts'
  },
  resolve: {
    extensions: ['.css', '.scss']
  }
}

export default generateWebpackConfig(customConfig)
```

### Step 2: Using JSDoc for Gradual Migration

If you're not ready for full TypeScript, use JSDoc in JavaScript:

```javascript
// webpack.config.js
const { generateWebpackConfig } = require('shakapacker')

/**
 * @type {import('webpack').Configuration}
 */
const customConfig = {
  entry: {
    application: './app/javascript/application.js'
  },
  resolve: {
    extensions: ['.css', '.scss'] // IDE will validate this!
  }
}

module.exports = generateWebpackConfig(customConfig)
```

## Advanced Configurations

### Environment-Specific Configuration

```typescript
// webpack.config.ts
import { generateWebpackConfig, env } from 'shakapacker'
import type { Configuration } from 'webpack'
import ForkTSCheckerWebpackPlugin from 'fork-ts-checker-webpack-plugin'

const customConfig: Configuration = {
  plugins: env.isDevelopment 
    ? [new ForkTSCheckerWebpackPlugin()]
    : [],
  
  optimization: {
    minimize: env.isProduction,
    splitChunks: env.isProduction 
      ? { chunks: 'all' }
      : false
  }
}

export default generateWebpackConfig(customConfig)
```

### Custom Loaders with Type Safety

```typescript
// webpack.config.ts
import { generateWebpackConfig, rules } from 'shakapacker'
import type { Configuration, RuleSetRule } from 'webpack'

const svgRule: RuleSetRule = {
  test: /\.svg$/,
  use: [{
    loader: '@svgr/webpack',
    options: {
      native: false,
      svgoConfig: {
        plugins: [{ removeViewBox: false }]
      }
    }
  }]
}

const customConfig: Configuration = {
  module: {
    rules: [...rules, svgRule]
  }
}

export default generateWebpackConfig(customConfig)
```

### Rspack Configuration

```typescript
// rspack.config.ts
import { generateRspackConfig } from 'shakapacker/rspack'
import type { RspackOptions } from '@rspack/core'

const customConfig: RspackOptions = {
  experiments: {
    css: true // Full type checking!
  },
  module: {
    rules: [{
      test: /\.tsx?$/,
      use: {
        loader: 'builtin:swc-loader',
        options: {
          sourceMap: true,
          jsc: {
            parser: {
              syntax: 'typescript',
              tsx: true
            }
          }
        }
      }
    }]
  }
}

export default generateRspackConfig(customConfig)
```

## IDE Support

### Visual Studio Code

**Recommended Extensions:**
- [TypeScript Vue Plugin](https://marketplace.visualstudio.com/items?itemName=Vue.vscode-typescript-vue-plugin) (for Vue users)
- [TypeScript Hero](https://marketplace.visualstudio.com/items?itemName=rbbit.typescript-hero)
- [Path Intellisense](https://marketplace.visualstudio.com/items?itemName=christian-kohler.path-intellisense)

**Settings (.vscode/settings.json):**
```json
{
  "typescript.tsdk": "node_modules/typescript/lib",
  "typescript.enablePromptUseWorkspaceTsdk": true,
  "editor.formatOnSave": true,
  "editor.defaultFormatter": "esbenp.prettier-vscode",
  "typescript.preferences.importModuleSpecifier": "relative"
}
```

### WebStorm / IntelliJ IDEA

1. Enable TypeScript service: Settings → Languages & Frameworks → TypeScript
2. Set TypeScript version to project's node_modules
3. Enable "Recompile on changes"

### Sublime Text

Install packages:
- TypeScript
- TypeScript Syntax
- SublimeLinter-tsc

## Common Patterns

### Pattern 1: Extracting Common Configuration

```typescript
// config/webpack/shared.ts
import type { Configuration } from 'webpack'

export const sharedConfig: Configuration = {
  resolve: {
    extensions: ['.js', '.jsx', '.ts', '.tsx']
  }
}

// config/webpack/development.ts
import { generateWebpackConfig } from 'shakapacker'
import { merge } from 'webpack-merge'
import { sharedConfig } from './shared'

export default generateWebpackConfig(
  merge(sharedConfig, {
    mode: 'development',
    devtool: 'eval-source-map'
  })
)
```

### Pattern 2: Plugin Configuration with Types

```typescript
// config/webpack/plugins.ts
import MiniCssExtractPlugin from 'mini-css-extract-plugin'
import CompressionPlugin from 'compression-webpack-plugin'
import { WebpackPluginInstance } from 'webpack'
import { env } from 'shakapacker'

export function getPlugins(): WebpackPluginInstance[] {
  const plugins: WebpackPluginInstance[] = [
    new MiniCssExtractPlugin({
      filename: env.isProduction 
        ? 'css/[name]-[contenthash].css'
        : 'css/[name].css'
    })
  ]

  if (env.isProduction) {
    plugins.push(
      new CompressionPlugin({
        test: /\.(js|css|html|json|ico|svg|eot|otf|ttf)$/,
        threshold: 10240
      })
    )
  }

  return plugins
}
```

### Pattern 3: Custom Dev Server Configuration

```typescript
// webpack.config.ts
import { generateWebpackConfig, config as shakapackerConfig } from 'shakapacker'
import type { Configuration } from 'webpack'
import type { Configuration as DevServerConfiguration } from 'webpack-dev-server'

const devServerConfig: DevServerConfiguration = {
  ...shakapackerConfig.dev_server,
  headers: {
    'Access-Control-Allow-Origin': '*'
  },
  onBeforeSetupMiddleware: (devServer) => {
    // Custom middleware with type safety
  }
}

const customConfig: Configuration = {
  devServer: devServerConfig
}

export default generateWebpackConfig(customConfig)
```

## Troubleshooting

### Issue: "Cannot find module 'shakapacker'"

**Solution:** Ensure TypeScript can find the type definitions:

```typescript
// webpack.config.ts
/// <reference types="shakapacker" />
import { generateWebpackConfig } from 'shakapacker'
```

### Issue: Type errors with custom loaders

**Solution:** Use type assertions or extend the types:

```typescript
import type { RuleSetRule } from 'webpack'

const customRule: RuleSetRule = {
  test: /\.mdx$/,
  use: [
    {
      loader: require.resolve('@mdx-js/loader'),
      options: {
        // Your options
      }
    } as any // Type assertion for untyped loaders
  ]
}
```

### Issue: Module resolution errors

**Solution:** Update your tsconfig.json:

```json
{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@/*": ["app/javascript/*"],
      "shakapacker": ["node_modules/shakapacker/package/index"]
    }
  }
}
```

## Migration Checklist

- [ ] Install TypeScript: `npm install --save-dev typescript @types/webpack`
- [ ] Create/update `tsconfig.json` in your project root
- [ ] Rename `webpack.config.js` to `webpack.config.ts`
- [ ] Add type imports and annotations
- [ ] Update npm scripts to use ts-node if needed
- [ ] Configure your IDE for TypeScript
- [ ] Test the build: `bin/shakapacker`
- [ ] Update CI/CD pipelines if necessary

## Benefits After Migration

1. **Compile-time Error Detection**: Catch configuration errors before runtime
2. **IDE Autocomplete**: Full IntelliSense for all configuration options
3. **Documentation**: Inline documentation on hover
4. **Refactoring Safety**: Rename and refactor with confidence
5. **Type Safety**: Ensure configuration values are the correct types

## Next Steps

- Read the [TypeScript Error Prevention Guide](./typescript-error-prevention.md)
- Review the [TypeScript Migration Guide](./typescript-migration-guide.md)
- Check the [official webpack TypeScript documentation](https://webpack.js.org/configuration/configuration-languages/#typescript)