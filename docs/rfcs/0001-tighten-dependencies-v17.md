# RFC: Tighten Dependencies for Shakapacker v17

**Status:** Draft
**Date:** 2026-03-28
**Author:** Justin Gordon

## Summary

Shakapacker v17 should dramatically simplify its dependency surface by tightening version ranges, dropping support for end-of-life runtimes, and clearly separating the two primary usage modes: **managed build** (Shakapacker configures webpack/rspack) and **custom build** (user provides their own build that outputs a manifest).

This is a breaking change by design. Major versions exist for exactly this purpose.

## Motivation

### The Current Problem

Shakapacker v9 has **23 optional peer dependencies** with extremely broad version ranges:

- `esbuild`: 14 separate version ranges (`^0.14.0 || ^0.15.0 || ... || ^0.27.0`)
- `webpack-cli`: 3 major versions (`^4.9.2 || ^5.0.0 || ^6.0.0`)
- `sass-loader`: 4 major versions (`^13.0.0 || ^14.0.0 || ^15.0.0 || ^16.0.0`)
- `babel-loader`: 3 major versions (`^8.2.4 || ^9.0.0 || ^10.0.0`)

On the Ruby side, the gem supports Rails 5.2+ and Ruby 2.7+ — both well past end-of-life.

This creates:

1. **Confusing install experience** — users see walls of peer dependency warnings and don't know which packages they actually need
2. **Enormous test/support matrix** — every version combination is a potential bug surface
3. **No clear "happy path"** — new users have to make too many decisions upfront
4. **Stale compatibility claims** — we can't realistically test webpack-cli 4.x anymore, yet we claim to support it

### How Modern Frameworks Handle This

**Next.js** has only **4 peer dependencies** (react, react-dom, sass, @opentelemetry/api — the latter two optional). Webpack is **vendored internally** — users never install or manage it. All loaders are pre-compiled into `next/dist/compiled/`. Their philosophy: users shouldn't think about build tooling.

**Vite** has **5 regular dependencies** and **12 peer dependencies** (ALL optional). The bundler (Rolldown) is a **pinned regular dependency**, not a peer dep. Only things users directly configure in their code (sass, less, stylus, terser) are peer deps. Most implementation dependencies (60+) are bundled into Vite's dist at build time.

**The key pattern:** both frameworks treat the bundler as an implementation detail they own. Peer dependencies are reserved for things users directly interact with in their own source code.

## Proposal

### Two Distinct Modes

Shakapacker serves two distinct user populations. v17 should make these modes explicit and optimize the dependency story for each.

#### Mode 1: Managed Build

Shakapacker generates and controls the webpack/rspack configuration. The user customizes via `shakapacker.yml` and optional config overrides.

**Users in this mode want:** a working build with minimal decisions. They chose Shakapacker so they wouldn't have to be webpack experts.

**Dependency strategy for managed build:**

The bundler and its core plugins should be **regular dependencies** (or tightly-pinned peer deps), not loose optional peers. Shakapacker should own the bundler version and guarantee it works.

Only things users add to their own source code remain as optional peer deps.

#### Mode 2: Custom Build

The user provides their own build process (any tool — webpack, rspack, Vite, esbuild, whatever). They only need Shakapacker for:

- Rails view helpers (`javascript_pack_tag`, `stylesheet_pack_tag`)
- Manifest reading (`manifest.json`)
- Dev server proxy
- Asset precompilation hooks

**Users in this mode want:** Shakapacker to stay out of their JS toolchain entirely.

**Dependency strategy for custom build:**

The npm package should work with **zero peer dependencies** in this mode. The user owns their entire JS toolchain. Shakapacker just reads the manifest they produce.

### Dependency Changes

#### npm package.json

##### Regular Dependencies (always installed)

| Package | Current | v17 Proposed | Notes |
|---------|---------|-------------|-------|
| js-yaml | `^4.1.0` | `^4.1.0` | No change |
| path-complete-extname | `^1.0.0` | `^1.0.0` | No change |
| webpack-merge | `^5.8.0` | `^5.8.0` | No change |
| yargs | `^17.7.2` | `^17.7.2` | No change |

##### Peer Dependencies — Webpack Path

| Package | Current | v17 Proposed | Change |
|---------|---------|-------------|--------|
| webpack | `^5.76.0` (optional) | `^5.90.0` | Raise floor; keep as peer dep but **required** when using webpack mode |
| webpack-cli | `^4.9.2 \|\| ^5.0.0 \|\| ^6.0.0` | `^6.0.0` | Drop v4, v5 |
| webpack-dev-server | `^4.15.2 \|\| ^5.2.2` | `^5.2.0` | Drop v4 |
| webpack-assets-manifest | `^5.0.6 \|\| ^6.0.0` | `^5.0.6` | Single major |
| mini-css-extract-plugin | `^2.0.0` | `^2.0.0` | No change |
| terser-webpack-plugin | `^5.3.1` | `^5.3.1` | No change |
| webpack-subresource-integrity | `^5.1.0` | `^5.1.0` | No change |
| compression-webpack-plugin | `^9 \|\| ^10 \|\| ^11 \|\| ^12` | **Remove** | Niche — custom builds can add it |

##### Peer Dependencies — Rspack Path

| Package | Current | v17 Proposed | Change |
|---------|---------|-------------|--------|
| @rspack/core | `^1.0.0 \|\| ^2.0.0-0` | `^2.0.0` | Drop v1; v2 is stable |
| @rspack/cli | `^1.0.0 \|\| ^2.0.0-0` | `^2.0.0` | Match core |
| rspack-manifest-plugin | `^5.0.0` | `^5.0.0` | No change |
| @rspack/plugin-react-refresh | `^1.0.0` | `^1.0.0` | No change (optional) |

##### Peer Dependencies — Transpiler

| Package | Current | v17 Proposed | Change |
|---------|---------|-------------|--------|
| @swc/core | `^1.3.0` | `^1.3.0` | Stays as default transpiler |
| swc-loader | `^0.1.15 \|\| ^0.2.0` | `^0.2.0` | Drop old range |
| @babel/core | `^7.17.9` | `^7.17.9` | Optional, legacy |
| @babel/plugin-transform-runtime | `^7.17.0` | `^7.17.0` | Optional, legacy |
| @babel/preset-env | `^7.16.11` | `^7.16.11` | Optional, legacy |
| @babel/runtime | `^7.17.9` | `^7.17.9` | Optional, legacy |
| babel-loader | `^8.2.4 \|\| ^9.0.0 \|\| ^10.0.0` | `^9.0.0` | Drop v8 |
| esbuild | 14 ranges (`^0.14.0` through `^0.27.0`) | `^0.24.0` | Single range |
| esbuild-loader | `^2.0.0 \|\| ^3.0.0 \|\| ^4.0.0` | `^4.0.0` | Drop v2, v3 |

##### Peer Dependencies — CSS & Styling (Optional)

| Package | Current | v17 Proposed | Change |
|---------|---------|-------------|--------|
| css-loader | `^6.8.1 \|\| ^7.0.0` | `^7.0.0` | Drop v6 |
| sass | `^1.50.0` | `^1.70.0` | Raise floor |
| sass-loader | `^13 \|\| ^14 \|\| ^15 \|\| ^16` | `^16.0.0` | Drop 3 old majors |

##### Removed Peer Dependencies

| Package | Reason |
|---------|--------|
| compression-webpack-plugin | Niche use case; custom builds handle this |
| @types/webpack | Dev concern, not a runtime peer dep |
| @types/babel__core | Dev concern, not a runtime peer dep |

##### Summary

| Metric | v9 (Current) | v17 (Proposed) |
|--------|-------------|----------------|
| Total peer dependencies | 23 | ~16 |
| Optional peer dependencies | 23 (all) | ~10 |
| Required peer dependencies | 0 | ~6 (depending on chosen bundler) |
| Distinct version ranges across all peer deps | 50+ | ~20 |

#### Ruby gemspec

| Dependency | Current | v17 Proposed | Reason |
|------------|---------|-------------|--------|
| `required_ruby_version` | `>= 2.7.0` | `>= 3.1.0` | Ruby 2.7 and 3.0 are EOL |
| `activesupport` | `>= 5.2` | `>= 7.0` | Rails 5.2, 6.0 are EOL |
| `railties` | `>= 5.2` | `>= 7.0` | Match activesupport |

#### Node.js engines

| Field | Current | v17 Proposed | Reason |
|-------|---------|-------------|--------|
| `engines.node` | `>= 20` | `>= 20` | No change (Node 20 is current LTS) |

### Required vs Optional Peer Dependencies

A key change in v17: peer dependencies for the **chosen bundler path** become **required** (not optional). This means:

**If `assets_bundler: "webpack"` in shakapacker.yml:**
- `webpack`, `webpack-cli`, `webpack-assets-manifest` are **required** peer deps
- `webpack-dev-server` is optional (only needed in dev)
- `@rspack/*` packages are irrelevant

**If `assets_bundler: "rspack"`:**
- `@rspack/core`, `@rspack/cli`, `rspack-manifest-plugin` are **required** peer deps
- `webpack-*` packages are irrelevant

**If `javascript_transpiler: "none"` (custom build):**
- No bundler or transpiler peer deps are required
- Shakapacker only needs its regular dependencies

This can be enforced via:
1. Runtime validation with clear error messages (already exists via `moduleExists()` checks)
2. An enhanced `shakapacker:doctor` task that validates installed deps against config
3. The installer generating the correct `package.json` dependencies based on chosen mode

### Installer Changes

The `shakapacker:install` rake task should be updated to:

1. Ask which bundler (webpack or rspack) — default: webpack
2. Ask which transpiler (swc, babel, esbuild, none) — default: swc
3. Install **only** the required dependencies for the chosen combination
4. Generate a `package.json` with exact dev dependencies, not ranges

Example for **webpack + swc** (the default happy path):

```json
{
  "devDependencies": {
    "shakapacker": "^17.0.0",
    "webpack": "^5.90.0",
    "webpack-cli": "^6.0.0",
    "webpack-assets-manifest": "^5.0.6",
    "webpack-dev-server": "^5.2.0",
    "@swc/core": "^1.3.0",
    "swc-loader": "^0.2.0",
    "css-loader": "^7.0.0",
    "mini-css-extract-plugin": "^2.0.0"
  }
}
```

Example for **rspack** (SWC is built-in):

```json
{
  "devDependencies": {
    "shakapacker": "^17.0.0",
    "@rspack/core": "^2.0.0",
    "@rspack/cli": "^2.0.0",
    "rspack-manifest-plugin": "^5.0.0",
    "css-loader": "^7.0.0"
  }
}
```

Example for **custom build** (manifest-only mode):

```json
{
  "devDependencies": {
    "shakapacker": "^17.0.0"
  }
}
```

## Migration Path

### For Managed Build Users

1. Update `shakapacker` gem and npm package to v17
2. Run `bundle exec rake shakapacker:doctor` — it will report outdated dependencies
3. Update dependencies to the new minimum versions
4. Remove dependencies that are no longer peer deps (e.g., `compression-webpack-plugin` if unused)

Most users on recent versions of webpack/rspack will only need to bump a few packages.

### For Custom Build Users

1. Update `shakapacker` gem and npm package to v17
2. Set `javascript_transpiler: "none"` in `shakapacker.yml` (if not already)
3. Remove any Shakapacker peer deps you installed but don't directly use
4. Ensure your custom build outputs `manifest.json` in the configured location

### For Babel Users

Babel is no longer the default and hasn't been since v9. In v17:
- Babel still works, but only `babel-loader` v9+ is supported
- Consider migrating to SWC (`javascript_transpiler: "swc"`) for 20x faster builds
- The transpiler migration guide already exists at `docs/transpiler-migration.md`

## Alternatives Considered

### Bundle webpack/rspack as a regular dependency (Next.js model)

We considered making webpack a regular dependency rather than a peer dep, similar to how Next.js vendors webpack. This was rejected because:

- Shakapacker supports **both** webpack and rspack — we can't bundle both
- Users need direct access to webpack/rspack for custom config files
- Shakapacker is a "build tool orchestrator," not an opinionated framework like Next.js
- Vendoring would make it harder for users to apply webpack security patches independently

### Create separate packages for webpack vs rspack

We considered splitting into `shakapacker-webpack` and `shakapacker-rspack`. This was rejected because:

- The Ruby gem is shared — the split only makes sense on the npm side
- The switching mechanism (`assets_bundler` config) works well today
- Two packages would double our release/maintenance burden
- Users migrating from webpack to rspack would need to switch packages

### Keep the status quo (all optional peer deps)

Rejected because the current approach provides no guardrails. Users installing Shakapacker for the first time have no idea which of the 23 optional peer deps they need. The `peerDependenciesMeta: optional` approach silences warnings but doesn't help users make correct choices.

## Open Questions

1. **Should `compression-webpack-plugin` be removed entirely or moved to documentation?** It's convenient but niche. Users with custom builds can add it themselves.

2. **Should we provide a `shakapacker:upgrade` task** that automatically updates `package.json` dependencies to the new minimum versions?

3. **Should the `assets_bundler` config support a third option like `"custom"` or `"none"`** to make custom build mode more explicit than `javascript_transpiler: "none"`?

4. **Should we consider pre-bundling more of our implementation deps** (like Vite does) to reduce the transitive dependency tree for users?

5. **What's the right floor for webpack?** The proposal says `^5.90.0`, but we could go higher. What's the oldest webpack 5.x version anyone reasonably uses?

## References

- [Current peer-dependencies docs](../peer-dependencies.md)
- [Current optional-peer-dependencies docs](../optional-peer-dependencies.md)
- [Next.js package.json](https://github.com/vercel/next.js/blob/canary/packages/next/package.json) — 4 peer deps, webpack vendored
- [Vite package.json](https://github.com/vitejs/vite/blob/main/packages/vite/package.json) — 5 deps, 12 optional peers, bundler pinned
- [Transpiler migration guide](../transpiler-migration.md)
