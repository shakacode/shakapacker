# JavaScript Transpiler Performance Guide

Shakapacker supports Babel, SWC, and esbuild for webpack-based JavaScript
transpilation. Rspack uses its built-in SWC-based loader by default.

This guide intentionally avoids exact benchmark numbers. Build performance
depends heavily on project size, loader configuration, source maps, minification,
cache state, hardware, and whether the measurement covers transpilation alone or
the full bundler pipeline.

## Summary

| Transpiler  | Performance Profile            | Configuration Profile | Best Fit                                     |
| ----------- | ------------------------------ | --------------------- | -------------------------------------------- |
| **SWC**     | Usually much faster than Babel | Moderate              | Default choice for most new Shakapacker apps |
| **esbuild** | Usually very fast              | Minimal               | Modern syntax with simple transform needs    |
| **Babel**   | Usually slowest                | Most flexible         | Existing Babel plugins or custom transforms  |

SWC is the recommended default for new Shakapacker apps because it usually gives
large speedups over Babel while covering the common JavaScript, TypeScript, and
React cases. esbuild can also be very fast, but its transform model is less
compatible with Babel-style plugin workflows.

## What Usually Affects Build Time

The transpiler is only one part of a Shakapacker build. Measure the whole build
before attributing performance to one tool.

Common factors:

- Source map mode
- TypeScript type-checking outside the transpiler
- Minification and CSS processing
- Babel plugin count and plugin behavior
- Webpack vs Rspack
- Filesystem cache state
- Number and size of entry points
- Number of files outside `node_modules` processed by rules
- CI hardware and CPU concurrency

When comparing options, run the same command several times after clearing or
warming caches intentionally. Record the command, environment, lockfile, and
Shakapacker config alongside the results.

## Choosing a Transpiler

### Choose SWC When

- You are starting a new app.
- You want a faster default than Babel without moving to Rspack yet.
- You use common JavaScript, TypeScript, JSX, or TSX transforms.
- You can configure the few project-specific SWC options you need in
  `config/swc.config.js`.

See [Using SWC Loader](./using_swc_loader.md).

### Choose esbuild When

- You target modern browsers or have a simple transpilation target.
- You do not rely on Babel plugins, Babel macros, or transform behavior that
  esbuild does not implement.
- You want a small configuration surface.

See [Using esbuild-loader](./using_esbuild_loader.md).

### Choose Babel When

- You already rely on Babel plugins or Babel macros.
- You need custom transforms that do not have SWC or esbuild equivalents.
- You have mature Babel configuration that is more important than raw build
  speed.
- You need compatibility with old browser targets that your SWC/esbuild setup
  does not cover.

See [Customizing Babel Config](./customizing_babel_config.md).

## Compatibility Tradeoffs

### SWC

Strengths:

- Fast Rust implementation
- JavaScript, TypeScript, JSX, and TSX support
- Good fit for React applications
- Works well with Shakapacker's default config

Watch for:

- Smaller plugin ecosystem than Babel
- Project-specific transform options may need `config/swc.config.js`
- Stimulus apps should preserve class names; see
  [Using SWC with Stimulus](./using_swc_loader.md#using-swc-with-stimulus)
- `.swcrc` can override Shakapacker defaults in surprising ways; prefer
  `config/swc.config.js`

### esbuild

Strengths:

- Very fast Go implementation
- Simple configuration
- Good fit for modern JavaScript and TypeScript transpilation

Watch for:

- Not a Babel-compatible plugin system
- Some TypeScript and transform options are intentionally unsupported
- Decorators and framework-specific transforms may need extra care

### Babel

Strengths:

- Largest plugin ecosystem
- Mature support for custom transformations
- Good fit for apps that already have working Babel config

Watch for:

- Slower builds on large codebases
- More configuration to maintain
- Plugin behavior can be hard to compare directly with SWC or esbuild

## How to Switch Transpilers

### SWC

```yaml
# config/shakapacker.yml
javascript_transpiler: "swc"
```

```bash
npm install @swc/core swc-loader
```

### esbuild

```yaml
# config/shakapacker.yml
javascript_transpiler: "esbuild"
```

```bash
npm install esbuild esbuild-loader
```

### Babel

```yaml
# config/shakapacker.yml
javascript_transpiler: "babel"
```

```bash
npm install babel-loader @babel/core @babel/preset-env
```

Replace `npm` with your app's package manager when using Yarn, pnpm, or Bun.

## Measuring Your App

Use your app's real build command rather than a synthetic number from another
project:

```bash
time bin/shakapacker
```

For development feedback, measure the dev server or watch workflow you actually
use:

```bash
time bin/shakapacker-dev-server
```

For CI, measure the full command sequence, including dependency install and
asset compilation if those are part of the job.

Record:

- Ruby, Node.js, package manager, and Shakapacker versions
- Bundler (`webpack` or `rspack`)
- Transpiler (`babel`, `swc`, or `esbuild`)
- `NODE_ENV` and `RAILS_ENV`
- Whether caches were warm or cold
- Source map and minification settings
- Hardware or CI runner type

## Migration Guidance

For most apps, migrate incrementally:

1. Commit the current working build.
2. Switch from Babel to SWC or esbuild.
3. Run the test suite and a production build.
4. Compare build output and browser behavior.
5. Keep Babel only for the paths that need Babel-specific transforms.

If you want the biggest bundler-level performance change, evaluate
[Rspack](./rspack_migration_guide.md) separately from the transpiler change so
you can attribute any regressions to the right layer.

See [Transpiler Migration](./transpiler-migration.md) for step-by-step migration
commands.
