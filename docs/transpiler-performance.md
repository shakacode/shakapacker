# JavaScript Transpiler Performance Guide

Shakapacker supports Babel, SWC, and esbuild for webpack-based JavaScript transpilation. Rspack uses its built-in SWC-based loader by default.

For most apps, moving off Babel is the single highest-impact change you can make to build performance. Moving from webpack to Rspack on top of that is usually the next biggest win. The numbers below come from the upstream projects' own published benchmarks, so treat them as a realistic upper bound rather than a guarantee for your app.

## Published Benchmarks

Use these as a starting point, then [measure your own app](#measuring-your-app):

- **SWC vs Babel**: SWC reports being **[20x faster than Babel on a single thread and 70x faster on four cores](https://swc.rs/)** on its own transpiler benchmark.
- **Rspack vs webpack**: The official Rspack landing page reports roughly **[10x faster development startup, ~8x faster production builds, and ~17x faster HMR](https://rspack.rs/)** on its reference React app, with [full benchmark sources in `rstackjs/build-tools-performance`](https://github.com/rstackjs/build-tools-performance). Numbers vary by case size; cold builds of the `react-5k` case run in roughly 1.6s on Rspack vs ~9.5s on webpack.
- **esbuild vs other bundlers**: esbuild's homepage benchmark bundles 10 copies of three.js in **[~0.4s with esbuild vs ~41s with webpack 5](https://esbuild.github.io/)** (minified, with source maps).

These are upstream micro-benchmarks. Your Shakapacker build also runs CSS processing, minification, source map generation, plugin chains, and Rails-side hooks, so end-to-end speedups are typically smaller than the transpiler or bundler number in isolation. They are still very substantial for most apps.

## Summary

| Transpiler  | Performance Profile (vs Babel)                            | Configuration Profile | Best Fit                                     |
| ----------- | --------------------------------------------------------- | --------------------- | -------------------------------------------- |
| **SWC**     | Much faster; upstream reports up to 20x / 70x multi-core¹ | Moderate              | Default choice for most new Shakapacker apps |
| **esbuild** | Very fast for supported transforms²                       | Minimal               | Modern syntax with simple transform needs    |
| **Babel**   | Baseline                                                  | Most flexible         | Existing Babel plugins or custom transforms  |

| Bundler     | Performance Profile (vs webpack)                              | Configuration Profile           | Best Fit                                               |
| ----------- | ------------------------------------------------------------- | ------------------------------- | ------------------------------------------------------ |
| **Rspack**  | Substantially faster; upstream reports roughly 8–17x typical³ | Mostly webpack-compatible       | Apps that want the biggest single performance jump     |
| **webpack** | Baseline                                                      | Largest plugin/loader ecosystem | Apps with webpack-only loaders or plugins they rely on |

¹ [swc.rs](https://swc.rs/) — "SWC is 20x faster than Babel on a single thread and 70x faster on four cores."
² [esbuild.github.io](https://esbuild.github.io/) — bundle of 10× three.js: esbuild ~0.4s vs webpack 5 ~41s.
³ [rspack.rs](https://rspack.rs/) and [rstackjs/build-tools-performance](https://github.com/rstackjs/build-tools-performance) — published numbers on the `react-5k` case.

**Recommended path for most apps:** SWC first (small change, large win on transpilation), then Rspack (larger change, large win on the full bundler pipeline). The combination is what produces the biggest end-to-end improvement.

## What Usually Affects Build Time

The transpiler is one part of a Shakapacker build. Measure the whole build before attributing performance to any single tool.

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

When comparing options, run the same command several times after clearing or warming caches intentionally. Record the command, environment, lockfile, and Shakapacker config alongside the results.

## Choosing a Transpiler

### Choose SWC When

- You are starting a new app.
- You want a faster default than Babel without moving to Rspack yet.
- You use common JavaScript, TypeScript, JSX, or TSX transforms.
- You can configure the few project-specific SWC options you need in `config/swc.config.js`.

See [Using SWC Loader](./using_swc_loader.md).

### Choose esbuild When

- You target modern browsers or have a simple transpilation target.
- You do not rely on Babel plugins, Babel macros, or transform behavior that esbuild does not implement.
- You want a small configuration surface.

See [Using esbuild-loader](./using_esbuild_loader.md).

### Choose Babel When

- You already rely on Babel plugins or Babel macros.
- You need custom transforms that do not have SWC or esbuild equivalents.
- You have mature Babel configuration that is more important than raw build speed.
- You need compatibility with old browser targets that your SWC/esbuild setup does not cover.

See [Customizing Babel Config](./customizing_babel_config.md).

## Compatibility Tradeoffs

### SWC

Strengths:

- Fast Rust implementation (upstream reports 20x/70x vs Babel¹)
- JavaScript, TypeScript, JSX, and TSX support
- Good fit for React applications
- Works well with Shakapacker's default config

Watch for:

- Smaller plugin ecosystem than Babel
- Project-specific transform options may need `config/swc.config.js`
- Stimulus apps should preserve class names; see [Using SWC with Stimulus](./using_swc_loader.md#using-swc-with-stimulus)
- `.swcrc` can override Shakapacker defaults in surprising ways; prefer `config/swc.config.js`

### esbuild

Strengths:

- Very fast Go implementation (upstream three.js benchmark shows ~100x vs webpack 5²)
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

The examples below use `npm`. Replace `npm` with your app's package manager when using Yarn, pnpm, or Bun.

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

## Measuring Your App

Published benchmarks measure transpilation or bundling in isolation on synthetic projects. Your Shakapacker build is the full pipeline, so always measure end-to-end with your real command before deciding what to keep or revert:

```bash
time bin/shakapacker
```

For development feedback, measure the dev server or watch workflow you actually use:

```bash
time bin/shakapacker-dev-server
```

For CI, measure the full command sequence, including dependency install and asset compilation if those are part of the job.

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

If you want the biggest bundler-level performance change, evaluate [Rspack](./rspack_migration_guide.md) as a separate step so you can attribute any regressions to the right layer. For most apps the combined **Rspack + SWC** path is the highest-leverage change available — see [Combined Migration Path](./common-upgrades.md#combined-migration-path).

See [Transpiler Migration](./transpiler-migration.md) for step-by-step migration commands.

## Sources

- SWC benchmark: [swc.rs](https://swc.rs/)
- Rspack benchmark: [rspack.rs](https://rspack.rs/) and [rstackjs/build-tools-performance](https://github.com/rstackjs/build-tools-performance)
- esbuild benchmark: [esbuild.github.io](https://esbuild.github.io/)
