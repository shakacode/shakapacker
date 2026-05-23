# Shakapacker 10.1: One-Package Installs with `shakapacker-rspack` and `shakapacker-webpack`

**Date:** 2026-05-10
**Author:** Justin Gordon

Shakapacker 10.1 ships two new optional npm packages — `shakapacker-rspack` and `shakapacker-webpack` — that turn a four-or-five-package install into one. Same Shakapacker, simpler `package.json`.

## The 30-second pitch

If you're starting a new app today on npm 7+, pnpm, or yarn 2+:

```sh
npm install --save-dev shakapacker-rspack
```

That's it. The required peers (`@rspack/core`, `@rspack/cli`, `rspack-manifest-plugin`) auto-install with the supplemental, and `shakapacker` comes along as a direct dependency. Webpack users get the same shape with `shakapacker-webpack`. (Yarn classic 1.x users need to list the required peers explicitly; the Rails installer handles this for you.)

If you're already on Shakapacker 10.0, you can collapse the now-managed deps in your `devDependencies` into the supplemental package. Nothing breaks if you don't.

## What changed

Until now, a typical Shakapacker install meant listing the gem, the npm package, the bundler, the bundler's CLI, the manifest plugin, and your transpiler — all as direct dependencies. That worked, but it pushed the version-matching problem onto every user. Were you on a tested combination? You had to read the changelog to find out.

10.1 shifts that responsibility to the supplemental packages. Each one declares the singleton bundler stack as **required peer dependencies** so modern package managers auto-install them while still surfacing version conflicts as warnings rather than silently installing duplicate copies of webpack:

- `shakapacker-rspack` requires `@rspack/core`, `@rspack/cli`, `rspack-manifest-plugin` as peers; `shakapacker` rides along as a direct dependency.
- `shakapacker-webpack` requires `webpack`, `webpack-cli`, `webpack-assets-manifest` as peers; `shakapacker` and `terser-webpack-plugin` ride along as direct dependencies.

Optional features — transpilers (swc / babel / esbuild for webpack), CSS preprocessors, dev-server, react-refresh — stay as opt-in `peerDependencies` so you only download what you actually use. (Bundling sass into every install would force a 10MB native-binding download on apps that don't even import a `.scss` file. We're not doing that.)

## Adopting in an existing app

Replace the explicit deps with the supplemental package:

```diff
 {
   "devDependencies": {
-    "shakapacker": "^10.0.0",
-    "@rspack/core": "^2.0.0",
-    "@rspack/cli": "^2.0.0",
-    "rspack-manifest-plugin": "^5.0.0"
+    "shakapacker-rspack": "~10.1.0"
   }
 }
```

Run `yarn install`. No changes to `config/shakapacker.yml`, `bin/shakapacker`, or your bundler config are required. The full step-by-step (including the webpack flow and the optional-peer cheatsheet) lives in [`docs/migration/v10.1-supplemental-packages.md`](../migration/v10.1-supplemental-packages.md).

## What if I don't want to migrate?

Don't. Adoption is opt-in for the entire 10.x line. Apps that keep their existing `package.json` will continue to work exactly as they did on 10.0. The supplemental packages are the recommended path for new projects and a cleanup for existing ones, not a forced upgrade.

## Runtime safety net

The supplemental packages emit two structured warnings (via Node's built-in `process.emitWarning`) when your config and your installed peers disagree:

- `SHAKAPACKER_BUNDLER_MISMATCH` — you installed `shakapacker-webpack` but `config/shakapacker.yml` says `assets_bundler: rspack` (or vice versa).
- `SHAKAPACKER_NO_TRANSPILER` — the configured `javascript_transpiler:` doesn't have its loader pair installed (e.g., `swc` configured but `@swc/core`/`swc-loader` aren't resolvable).

Both are visible by default in dev and CI, suppressible with `--no-warnings`, and fire before your bundler throws a confusing module-not-found error.

## Looking ahead to v11

v11 will make the supplemental packages required for managed builds — core `shakapacker` will stop declaring bundler peer deps and apps that haven't adopted a supplemental package will need to switch. Custom-build users (apps that produce their own `manifest.json` from Vite, esbuild, or a hand-rolled webpack config) keep using bare `shakapacker` and aren't affected.

There's no firm v11 date yet. The 10.1 line is intentionally a soak period — we want real-world adoption signal on the supplemental packages before locking the design in. The full design rationale and roadmap lives in [`docs/dependency-strategy.md`](../dependency-strategy.md).

## Try it

- Migration guide: [`docs/migration/v10.1-supplemental-packages.md`](../migration/v10.1-supplemental-packages.md)
- `shakapacker-rspack` README: [`packages/shakapacker-rspack/README.md`](../../packages/shakapacker-rspack/README.md)
- `shakapacker-webpack` README: [`packages/shakapacker-webpack/README.md`](../../packages/shakapacker-webpack/README.md)
- Design rationale: [`docs/dependency-strategy.md`](../dependency-strategy.md)

Bug reports, feedback, and "this didn't work for me" stories all welcome on [GitHub issues](https://github.com/shakacode/shakapacker/issues) — we're using the 10.1 soak window to find rough edges before v11 closes the door.
