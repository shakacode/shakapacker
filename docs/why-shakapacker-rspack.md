# Why Shakapacker with Rspack for Rails

This guide explains where Shakapacker — especially paired with [Rspack](https://rspack.rs/) — fits among the JavaScript options available to a Rails app, and when one of the alternatives is the better call. The goal is an honest comparison, not a sales pitch: every approach here is a legitimate choice for the right app.

If you've already decided on Shakapacker and just want speed, jump to [Why Rspack over webpack](#why-rspack-over-webpack) or the [Transpiler Performance Guide](./transpiler-performance.md).

## TL;DR

- **Shakapacker** gives you a Rails-native, manifest-backed bridge to a full bundler (webpack 5 or Rspack), with view helpers, HMR/React Fast Refresh, code splitting, SRI, CDN hosts, and HTTP 103 Early Hints. It's the actively maintained successor to [rails/webpacker](https://github.com/rails/webpacker).
- **Rspack** is a Rust-based, mostly webpack-compatible bundler. On top of Shakapacker it's usually the single biggest build-speed win — upstream benchmarks report roughly **8x faster production builds, 10–15x faster dev startup, and ~17x faster HMR** versus webpack ([rspack.rs](https://rspack.rs/), [benchmark sources](https://github.com/rstackjs/build-tools-performance)).
- **Pick Shakapacker + Rspack** when you have a real frontend — React/Vue/TypeScript, code splitting, a large npm dependency tree, custom loaders/plugins — and you want fast builds with deep Rails integration.
- **Pick something simpler** (importmaps, jsbundling-rails) when your JavaScript is modest and you'd rather not run a full bundler. **Pick vite-rails** if you're committed to the Vite/Rollup ecosystem and its dev model.

## The Rails JavaScript landscape

Rails ships with sensible defaults, but "how do I build my JavaScript?" has several answers depending on how much frontend you have:

| Approach             | What it does                                                                | Build step           | Rails integration                      |
| -------------------- | --------------------------------------------------------------------------- | -------------------- | -------------------------------------- |
| **importmap-rails**  | Serves your JS as native ES modules, pinned and delivered over HTTP/2       | None                 | Asset pipeline (Propshaft/Sprockets)   |
| **jsbundling-rails** | Thin wrapper that runs esbuild/rollup/webpack via a `package.json` script   | Yes (bring your own) | Asset pipeline fingerprints the output |
| **vite-rails**       | Integrates [Vite](https://vitejs.dev/) (ESM dev server + Rollup prod build) | Yes (Vite)           | Vite manifest + view helpers           |
| **Shakapacker**      | Manifest-backed bridge to webpack 5 or Rspack                               | Yes (webpack/Rspack) | Native manifest + view helpers         |

These aren't strictly ranked — they trade build complexity for frontend capability. The rest of this guide walks each one and where Shakapacker pulls ahead.

## importmap-rails (the Rails 7/8 default)

[importmap-rails](https://github.com/rails/importmap-rails) skips bundling entirely. You write ES modules, pin your dependencies, and the browser loads them directly over HTTP/2 — no Node toolchain required at runtime.

**Great when:**

- Your app is Hotwire / HTML-over-the-wire with modest, hand-written JavaScript.
- You want the simplest possible setup and no build pipeline to maintain.

**You'll outgrow it when:**

- You need **JSX, TypeScript, or any transpilation** — the browser runs exactly what you ship, so there's no JSX/TS step.
- You want **tree-shaking, minification, or bundling** — importmaps deliver modules as-is, with no dead-code elimination or minification, so you ship the full published source of every dependency. HTTP/2 makes serving many files cheap, but it doesn't shrink what you send or remove code paths you never call.
- You depend on **npm packages that aren't published as browser-ready ESM**, or that expect a bundler's resolution and `process.env` handling.

Shakapacker exists precisely for the apps that have crossed that line: a real component framework, a large dependency graph, and a need to optimize what reaches the browser.

## jsbundling-rails

[jsbundling-rails](https://github.com/rails/jsbundling-rails) is a thin convention layer: it runs esbuild, rollup, or webpack through a `package.json` build script, writes the output to `app/assets/builds`, and lets Sprockets or Propshaft fingerprint and serve it.

**Great when:**

- You want a minimal, "bring your own bundler" setup and you're comfortable wiring the bundler config yourself.
- Your asset needs are simple enough that the standard asset pipeline digesting is all the integration you need.

**Where Shakapacker pulls ahead:**

- **Manifest-aware view helpers.** Shakapacker reads the bundler's own manifest, so `javascript_pack_tag`/`stylesheet_pack_tag` resolve entrypoints, chunks, and split-out CSS automatically. With jsbundling-rails you lean on the asset pipeline's digest and manage entrypoints more manually.
- **First-class dev server + HMR.** Shakapacker ships a configured dev server with Hot Module Replacement and React Fast Refresh. jsbundling-rails typically gives you `--watch` plus a full page reload.
- **Code splitting, SRI, CDN hosts, and HTTP 103 Early Hints** are wired into the Rails layer rather than left to you to assemble.

See the upstream [comparison with Webpacker](https://github.com/rails/jsbundling-rails/blob/main/docs/comparison_with_webpacker.md) and the in-depth decidim discussion ([#8783](https://github.com/decidim/decidim/discussions/8783)) and migration ([#10389](https://github.com/decidim/decidim/pull/10389)) for real-world reasoning on choosing between the two.

## vite-rails

[vite-rails](https://vite-ruby.netlify.app/) is the closest peer to Shakapacker: a modern integration with a manifest, view helpers, and HMR. Vite uses a native-ESM dev server (with esbuild pre-bundling dependencies) and Rollup for production builds, which makes its dev startup feel instant.

It's a genuinely strong choice. The differences are mostly about **ecosystem and model**, not "better/worse":

- **Plugin/loader ecosystem.** Shakapacker targets the webpack/Rspack ecosystem — one of the largest collections of loaders and plugins in the JS world, and the path most existing Rails+webpack apps are already on. Vite targets the Rollup/Vite plugin ecosystem.
- **Dev/prod symmetry.** Vite serves unbundled ESM in dev and bundles with Rollup in production; the two paths differ by design. Webpack/Rspack bundle in both dev and prod, which some teams prefer for fewer "works in dev, breaks in prod" surprises.
- **Migration path.** If you're coming from rails/webpacker or an existing webpack config, Shakapacker is a far smaller jump — much of your loader/plugin config carries over, especially with Rspack's webpack compatibility.

If you're starting greenfield and happy to live in the Vite ecosystem, vite-rails is excellent. If you're on webpack today, want maximum plugin compatibility, or want the webpack-to-Rust upgrade path described below, Shakapacker is the smoother road.

## Why Shakapacker

Shakapacker's value is that it makes a full-featured bundler feel like a native part of Rails:

- **Rails-native manifest integration and view helpers** for bundled assets.
- **Choice of bundler:** webpack 5 or first-class **Rspack** builds — switch with a single `assets_bundler` setting.
- **Choice of transpiler:** SWC, Babel, or esbuild for JavaScript/TypeScript.
- **Dev binstubs**, watch mode, dev server, **HMR, and React Fast Refresh** out of the box.
- **Code splitting, CDN asset hosts, Subresource Integrity (SRI), and HTTP 103 Early Hints.**
- **Package-manager agnostic:** npm, Yarn, pnpm, and Bun.
- Optional [`shakapacker-webpack` / `shakapacker-rspack`](./migration/v10.1-supplemental-packages.md) packages in 10.1+ that consolidate the managed bundler stack into one dependency.

Because it's the direct successor to rails/webpacker, existing Webpacker apps migrate with minimal config churn. See the [installation guide](./installation.md) to get started.

## Why Rspack over webpack

Once you're on Shakapacker, Rspack is usually the biggest single performance jump available — and because it's largely webpack API-compatible, switching is mostly a config flag rather than a rewrite.

Upstream benchmarks on the reference `react-5k` app report:

- **~8x faster production builds**
- **~10–15x faster development startup**
- **~17x faster HMR**
- **Lower memory usage** in most reported cases

(Source: [rspack.rs](https://rspack.rs/) and [rstackjs/build-tools-performance](https://github.com/rstackjs/build-tools-performance). Real-world gains depend on project size, source maps, cache state, and hardware — treat these as an upper bound and [measure your own app](./transpiler-performance.md#measuring-your-app).)

Real-world data point — Academia.edu, migrating webpack → Rspack with ShakaCode's help (March 2026):

> The impact has been between a **2–4x build speed increase** depending on the environment and conditions. The typical case of first startup with a warm cache has gone from roughly 1m with Webpack down to about **20s**. Production **incremental** builds now take around **10s** when only a few lines in one bundle have changed.

Rspack v2 adds stable persistent caching, stable incremental compilation, and improved tree shaking, plus experimental low-level support for React Server Components. See [Rspack Integration](./rspack.md) for setup and the full v2 rundown.

**Stay on webpack when** you depend on a loader or plugin that doesn't yet have an Rspack-compatible equivalent. Shakapacker supports both, so you can adopt Rspack when your plugin chain is ready.

## Recommended path for most apps

From the [Transpiler Performance Guide](./transpiler-performance.md):

1. **Move off Babel to SWC first** — a small config change with a large transpilation win.
2. **Then move from webpack to Rspack** — a larger change with a large win across the whole bundler pipeline.

The combination is what produces the biggest end-to-end improvement.

## How to choose, in one table

| Your situation                                                                                                                                                    | Best fit                   |
| ----------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------- |
| Minimal, hand-written JS; Hotwire app; no build step wanted                                                                                                       | **importmap-rails**        |
| Simple bundling needs; want a thin "bring your own bundler" wrapper                                                                                               | **jsbundling-rails**       |
| Greenfield, committed to the Vite/Rollup ecosystem and its dev model                                                                                              | **vite-rails**             |
| Real frontend (React/Vue/TS), code splitting, large npm tree, custom loaders/plugins; coming from webpack/Webpacker; want fast builds with deep Rails integration | **Shakapacker (+ Rspack)** |

## Further reading

- [Installation](./installation.md)
- [Rspack Integration](./rspack.md)
- [Transpiler Performance Guide](./transpiler-performance.md)
- [Webpack-to-Rspack Migration](./rspack_migration_guide.md)
- [Generated webpack vs. Rspack config diff](./config-diff.md)
