# Dependency Strategy

**Status:** v10.1 phase shipped (supplemental packages additive). v11 phase is the working roadmap, not a scheduled release.
**Original RFC date:** 2026-03-28 (revised 2026-05-10)
**Author:** Justin Gordon

> **Looking for the user-facing migration steps?** See [`docs/migration/v10.1-supplemental-packages.md`](migration/v10.1-supplemental-packages.md). This doc captures the design rationale, alternatives considered, and the v11 roadmap — read it if you want to understand _why_ the dependency surface looks the way it does.

## Summary

Shakapacker is split into **three npm packages** to cleanly separate concerns:

1. **`shakapacker`** — core package (config loading, manifest reading, dev server proxy, CLI). Zero bundler-specific peer deps.
2. **`shakapacker-webpack`** — managed webpack build. **Declares `webpack`, `webpack-cli`, `webpack-assets-manifest` as required peer dependencies** so the host app owns the singleton bundler stack. npm 7+ can auto-install them; pnpm and Yarn PnP users should list packages imported by app config files directly. `terser-webpack-plugin` (imported directly by core's default minimizer) ships as a direct `dependency`.
3. **`shakapacker-rspack`** — managed rspack build. **Declares `@rspack/core`, `@rspack/cli`, `rspack-manifest-plugin` as required peer dependencies** — same singleton guarantee.

> **Why peer deps instead of direct dependencies?** Bundler packages (`webpack`, `@rspack/core`) are singletons — plugin and loader code checks `compiler instanceof webpack.Compiler` and shares types like `webpack.Compilation`. Two copies in the tree silently break those checks. Required peer dependencies surface version conflicts instead of hiding them as silent duplicate installs. See [issue #1131](https://github.com/shakacode/shakapacker/issues/1131) for the discussion that led to this shape. npm 7+ auto-installs required peers; pnpm and Yarn PnP users should keep packages imported by app config files as explicit app dependencies (the Rails installer handles this automatically).

The rollout is phased:

- **v10.1.0 (shipped, non-breaking)** — supplemental packages are published as additive. Existing peer deps remain in core. Adopters opt in whenever they're ready.
- **v11.0.0 (planned, no firm date)** — supplemental packages become required for managed builds; core no longer declares bundler peer deps. Older bundler/loader versions and EOL Ruby/Rails versions get dropped. Specifics are sketched in §"Phase 2" below but the timing depends on adoption signal from v10.1.

## Motivation

### The Current Problem

Shakapacker v10 has **23 optional peer dependencies** with extremely broad version ranges:

- `esbuild`: 14 separate version ranges (`^0.14.0 || ^0.15.0 || ... || ^0.27.0`)
- `webpack-cli`: 4 major versions (`^4.9.2 || ^5.0.0 || ^6.0.0 || ^7.0.0`)
- `sass-loader`: 5 major versions (`^13.0.0 || ^14.0.0 || ^15.0.0 || ^16.0.0 || ^17.0.0`)
- `babel-loader`: 3 major versions (`^8.2.4 || ^9.0.0 || ^10.0.0`)

On the Ruby side, the gem supports Rails 5.2+ and Ruby 2.7+ — both well past end-of-life.

This creates:

1. **Confusing install experience** — users see walls of peer dependency warnings and don't know which packages they actually need
2. **Enormous test/support matrix** — every version combination is a potential bug surface
3. **No clear "happy path"** — new users have to make too many decisions upfront
4. **Stale compatibility claims** — we can't realistically test webpack-cli 4.x anymore, yet we claim to support it
5. **No way to express conditional requirements** — `package.json` peer deps are either optional or required for everyone; there's no "required if you picked webpack" semantic

### How Modern Frameworks Handle This

**Next.js** has only **4 peer dependencies** (react, react-dom, sass, @opentelemetry/api — the latter two optional). Webpack is **vendored internally** — users never install or manage it. All loaders are pre-compiled into `next/dist/compiled/`. Their philosophy: users shouldn't think about build tooling.

**Vite** has **5 regular dependencies** and **12 peer dependencies** (ALL optional). Only things users directly configure in their code (sass, less, stylus, terser) are peer deps. Most implementation dependencies (60+) are bundled into Vite's dist at build time. Note: Vite's bundler (previously esbuild/rollup, now rolldown) has historically used caret ranges — the current pinned rolldown version is because rolldown is still pre-release.

**The key pattern:** both frameworks minimize their peer dependency surface. Peer dependencies are reserved for things users directly interact with in their own source code.

## Proposal

### Phase 1: v10.1.0 (Non-Breaking, Additive)

Add the two supplemental packages. **No changes to the core `shakapacker` package's peer deps.** Existing users who do not adopt a supplemental package are unaffected. Early adopters of the supplemental packages opt into a curated managed stack while still allowing upstream semver-compatible updates.

What ships:

- Create `packages/shakapacker-webpack/` and `packages/shakapacker-rspack/`
- Core `package/` directory stays in place (NOT moved to `packages/shakapacker/`)
- Do not enable root `workspaces` yet: the root `package.json` is also the publishable `shakapacker` package, and Yarn Classic requires workspace roots to be `private: true`
- Publish core `shakapacker` 10.1.0 first, then publish supplemental packages at v10.1.0 so their core peer deps resolve
- Update docs and installer to recommend the new pattern for new projects
- Core `shakapacker` still declares all existing peer deps (nothing removed)
- Supplemental peer ranges align with main `shakapacker`'s peer ranges (caret ranges with sensible floors) so the supplemental never _narrows_ what bare core would accept. The supplemental is allowed to drop legacy versions where the curated stack moves forward (e.g., `webpack-cli` v7+ only, `webpack-assets-manifest` v6+ due to a v5 ENOENT bug).
- `shakapacker-webpack` early adopters move to `webpack-dev-server` 5.x with the supplemental package; webpack-dev-server 4.x remains tolerated only through the legacy core optional peer range during the v10.x compatibility window

Moving `package/` to `packages/shakapacker/` is deferred to v11.0.0 because it changes the published npm package layout (potential deep-import breakage for `shakapacker/package/*` paths) and requires resolving how `lib/install/config/shakapacker.yml` is included in the npm publish.

This gives the supplemental packages real-world usage before they become the required path, while making the "known good" dependency set visible immediately.

### Phase 2: v11.0.0 (Breaking)

Remove bundler-specific peer deps from core `shakapacker`. Tighten version ranges. Drop EOL runtimes.

What ships:

- Core `shakapacker` no longer declares webpack/rspack peer deps
- Users must install `shakapacker-webpack` or `shakapacker-rspack`
- Drop old major versions (webpack-cli v4/v5, sass-loader v13-15, etc.)
- Collapse esbuild from 14 ranges to `>=0.24.0 <1.0.0` (caret on 0.x locks to the minor in npm semver, so a literal `<1.0.0` ceiling is required to keep esbuild 0.25+ in scope)
- Ruby 3.4+, Rails 7.2+ (Ruby 3.1/3.2 are EOL; Ruby 3.3 reaches EOL 2027-03; Rails 7.0/7.1 are unsupported)

### Three npm Packages

The fundamental insight (credit: [G-Rath's feedback](https://github.com/shakacode/shakapacker/issues/1030#issuecomment-4150937493)) is that `package.json` cannot express conditional peer dependencies. Making all bundler deps required bloats everyone's install. Keeping them all optional provides no guardrails. **Separate packages solve this cleanly.**

#### `shakapacker` (core)

The base package that all users install. Contains:

- Config loading (`shakapacker.yml` parsing, defaults)
- Manifest reading and asset lookup
- Dev server proxy client
- CLI entry points (`shakapacker`, `shakapacker-dev-server`)
- View helper support (Ruby gem reads manifest generated by any build)
- Shared utilities (`webpack-merge`, config merging)

**Dependencies (v10.1.0 — no change from today):**

| Package               | Version     | Type              |
| --------------------- | ----------- | ----------------- |
| js-yaml               | `^4.1.0`    | dependency        |
| path-complete-extname | `^1.0.0`    | dependency        |
| webpack-merge         | `^5.8.0`    | dependency        |
| yargs                 | `^17.7.2`   | dependency        |
| All current peer deps | (unchanged) | optional peer dep |

**Dependencies (v11.0.0 — stripped down):**

| Package               | Version   | Type              |
| --------------------- | --------- | ----------------- |
| js-yaml               | `^4.1.0`  | dependency        |
| path-complete-extname | `^1.0.0`  | dependency        |
| webpack-merge         | `^5.8.0`  | dependency        |
| yargs                 | `^17.7.2` | dependency        |
| @types/webpack        | `^5.0.0`  | optional peer dep |
| @types/babel\_\_core  | `^7.0.0`  | optional peer dep |

**No bundler or transpiler peer deps in v11.** This package works standalone for custom build users.

The `@types/*` packages remain as optional peer deps because they are referenced by Shakapacker's exported TypeScript types. Users who consume the types need them; others don't.

#### `shakapacker-webpack` (managed webpack build)

Supplemental package for the standard webpack managed build experience.

> The "Range" column shows the actual `package.json` constraint. Bundler singletons (webpack, webpack-cli, webpack-assets-manifest) are required peer dependencies — npm 7+ auto-installs them, while pnpm and Yarn PnP users should list direct app imports explicitly.

**Direct dependencies (always installed):**

| Package               | Range          | Reason                                                                                                      |
| --------------------- | -------------- | ----------------------------------------------------------------------------------------------------------- |
| shakapacker           | `~10.1.0-rc.1` | Tilde locks to the lockstep release line (the wrapper imports core's internal `package/config` subpath).    |
| terser-webpack-plugin | `^5.3.1`       | `package/optimization/webpack.ts` does `requireOrError("terser-webpack-plugin")` for the default minimizer. |

**Required peer dependencies (singleton bundler stack):**

| Package                 | Range      | Reason                                                                                            |
| ----------------------- | ---------- | ------------------------------------------------------------------------------------------------- |
| webpack                 | `^5.101.0` | Singleton — plugins/loaders check `instanceof webpack.Compiler`. Matches main `shakapacker` peer. |
| webpack-cli             | `^7.0.0`   | Supplemental's curated stack drops older v4–v6 (main core still accepts them for legacy users).   |
| webpack-assets-manifest | `^6.0.0`   | v5 has an ENOENT crash on clean builds with `merge: true`; supplemental requires v6+.             |

**Peer dependencies (optional):**

| Package                              | Range                | When needed       |
| ------------------------------------ | -------------------- | ----------------- |
| webpack-dev-server                   | `^5.2.2`             | Dev mode with HMR |
| mini-css-extract-plugin              | `^2.0.0`             | CSS extraction    |
| webpack-subresource-integrity        | `^5.1.0`             | SRI hashes        |
| @pmmmwh/react-refresh-webpack-plugin | `^0.5.0 \|\| ^0.6.0` | React HMR         |

**Peer dependencies (optional — transpiler, pick one):**

| Package        | Range                             | When needed                              |
| -------------- | --------------------------------- | ---------------------------------------- |
| @swc/core      | `^1.3.0`                          | `javascript_transpiler: "swc"` (default) |
| swc-loader     | `^0.1.15 \|\| ^0.2.0`             | Paired with @swc/core                    |
| @babel/core    | `^7.17.9`                         | `javascript_transpiler: "babel"`         |
| babel-loader   | `^8.2.4 \|\| ^9.0.0 \|\| ^10.0.0` | Paired with @babel/core                  |
| esbuild        | `>=0.14.0 <1.0.0`                 | `javascript_transpiler: "esbuild"`       |
| esbuild-loader | `^2.0.0 \|\| ^3.0.0 \|\| ^4.0.0`  | Paired with esbuild                      |

**Peer dependencies (optional — CSS preprocessors):**

| Package     | Range                                                         | When needed      |
| ----------- | ------------------------------------------------------------- | ---------------- |
| css-loader  | `^6.8.1 \|\| ^7.0.0`                                          | CSS processing   |
| sass        | `^1.50.0`                                                     | SCSS/Sass files  |
| sass-loader | `^13.0.0 \|\| ^14.0.0 \|\| ^15.0.0 \|\| ^16.0.0 \|\| ^17.0.0` | Paired with sass |

#### `shakapacker-rspack` (managed rspack build)

Supplemental package for the rspack managed build experience.

**Direct dependencies (always installed):**

| Package     | Range          | Reason                                                                                                   |
| ----------- | -------------- | -------------------------------------------------------------------------------------------------------- |
| shakapacker | `~10.1.0-rc.1` | Tilde locks to the lockstep release line (the wrapper imports core's internal `package/config` subpath). |

**Required peer dependencies (singleton bundler stack):**

| Package                | Range    | Reason                                                                 |
| ---------------------- | -------- | ---------------------------------------------------------------------- |
| @rspack/core           | `^2.0.0` | Singleton — rspack plugins do the same `instanceof` checks as webpack. |
| @rspack/cli            | `^2.0.0` | `bin/shakapacker` shells out to the `rspack` CLI binary.               |
| rspack-manifest-plugin | `^5.0.0` | Generates the manifest the Rails view helpers read.                    |

**Peer dependencies (optional):**

| Package                      | Range                                                         | When needed      |
| ---------------------------- | ------------------------------------------------------------- | ---------------- |
| @rspack/plugin-react-refresh | `^1.0.0 \|\| ^2.0.0`                                          | React HMR        |
| css-loader                   | `^6.8.1 \|\| ^7.0.0`                                          | CSS processing   |
| sass                         | `^1.50.0`                                                     | SCSS/Sass files  |
| sass-loader                  | `^13.0.0 \|\| ^14.0.0 \|\| ^15.0.0 \|\| ^16.0.0 \|\| ^17.0.0` | Paired with sass |

Note: rspack has built-in SWC transpilation, so no external transpiler deps are needed.

Rspack v2 is stable, so the supplemental rspack package pins to the current v2 GA line. Older Rspack v1 and v2 pre-releases remain allowed only through the legacy optional peer ranges in core `shakapacker` during the v10.x compatibility window.

GA release-prep note: while 10.1 is still in release-candidate state, the dependency tables intentionally show `~10.1.0-rc.1` for the lockstep `shakapacker` dependency. Update those rows and examples to `~10.1.0` when publishing the GA supplemental packages.

### Version Pinning Philosophy

The core `shakapacker` package keeps its broad optional peer ranges during v10.x so existing applications are not broken by an additive release. The supplemental packages use a different policy — but **not** the strictest one.

- **Lockstep only for `shakapacker`.** The wrapper's `dependencies.shakapacker` uses a tilde (`~10.1.0-rc.1`) because the wrapper's runtime code calls into core's internal `package/config` subpath; mismatched minors could break that. All _other_ constraints use caret ranges with sensible floors.
- **Caret ranges for everything else.** Webpack, rspack, loaders, transpilers, and CSS preprocessors all use `^` so a routine upstream patch or minor release is immediately available to users without a coordinated Shakapacker release. The earlier RC pinned everything with `~`, which was reverted after [issue #1131](https://github.com/shakacode/shakapacker/issues/1131) pointed out the release-cadence trap (every upstream minor would obligate a supplemental release).
- **Align with main `shakapacker`'s peer ranges.** Where a peer appears in both main and a supplemental, the supplemental uses the same range (or narrower only when the curated stack deliberately drops legacy versions, e.g., `webpack-cli` v4–v6 or `webpack-assets-manifest` v5). The supplemental is never _stricter_ than main for an overlapping peer.
- **Avoid pre-release pins unless deliberately testing a pre-release line.** For example, `webpack-subresource-integrity` stays on the latest stable 5.1.x release even though its npm `latest` dist-tag currently points at a release candidate.

### What Each User Type Installs (v11+)

`shakapacker-webpack` and `shakapacker-rspack` declare the singleton bundler stack as **required peer dependencies**. npm 7+ can auto-install those peers with the supplemental. pnpm and Yarn PnP users should keep packages imported by app config files (`shakapacker`, and often the bundler packages) as explicit app dependencies unless their configs import the wrapper packages directly.

**Webpack + SWC:**

```json
{
  "devDependencies": {
    "shakapacker-webpack": "^11.0.0",
    "webpack-dev-server": "^5.2.2",
    "@swc/core": "^1.3.0",
    "swc-loader": "^0.2.0",
    "css-loader": "^7.0.0",
    "mini-css-extract-plugin": "^2.0.0"
  }
}
```

`shakapacker` and `terser-webpack-plugin` come along as direct dependencies of `shakapacker-webpack`. npm 7+ auto-installs `webpack`, `webpack-cli`, and `webpack-assets-manifest` via the required peer declarations. pnpm and Yarn PnP users should list them directly if app config files import them.

**Rspack — new-install default (SWC is built-in):**

```json
{
  "devDependencies": {
    "shakapacker-rspack": "^11.0.0",
    "css-loader": "^7.0.0"
  }
}
```

`shakapacker` comes along as a direct dependency. npm 7+ auto-installs `@rspack/core`, `@rspack/cli`, and `rspack-manifest-plugin` via the required peer declarations. pnpm and Yarn PnP users should list them directly if app config files import them.

**Custom build (manifest-only):**

```json
{
  "devDependencies": {
    "shakapacker": "^11.0.0"
  }
}
```

### Monorepo Structure

All three npm packages live in the existing `shakacode/shakapacker` repository. The Ruby gem also stays in this repo.

**Phase 1 (v10.1.0) — core stays in place:**

```text
shakapacker/
├── package/                    # core npm package source (unchanged)
│   └── ...
├── packages/
│   ├── shakapacker-webpack/    # supplemental webpack package
│   │   ├── package.json
│   │   └── index.js            # re-exports shakapacker root (per-bundler subpath split deferred to Phase 2)
│   └── shakapacker-rspack/     # supplemental rspack package
│       ├── package.json
│       └── index.js            # re-exports shakapacker/rspack
├── lib/                        # Ruby gem (unchanged)
├── spec/                       # Ruby specs
├── test/                       # JS tests
├── shakapacker.gemspec
└── package.json                # core npm package
```

**Phase 2 (v11.0.0) — core moves into packages/:**

```text
shakapacker/
├── packages/
│   ├── shakapacker/            # core npm package (moved from package/)
│   │   ├── package.json
│   │   └── ...
│   ├── shakapacker-webpack/    # supplemental webpack package
│   │   ├── package.json
│   │   └── index.js
│   └── shakapacker-rspack/     # supplemental rspack package
│       ├── package.json
│       └── index.js
├── lib/                        # Ruby gem (unchanged)
├── spec/                       # Ruby specs
├── test/                       # JS tests
├── shakapacker.gemspec
└── package.json                # workspace root
```

The supplemental packages are thin — primarily:

- `package.json` with the correct peer dependencies declared
- Re-exports of the bundler-specific config generation from the core `shakapacker` package
- Bundler-specific loader rules and plugin configurations

The core `shakapacker` package retains all the shared logic. The supplemental packages are essentially "dependency declarations + bundler-specific glue."

**Why monorepo, not separate repos:**

- Core changes almost always affect supplemental packages (config loading, loader rule composition, plugin wiring). Separate repos would mean coordinating releases constantly.
- Atomic commits — a single PR can update core + both supplemental packages + tests.
- One CI pipeline tests all three packages together.
- The supplemental packages are too thin to justify independent repos.

### Versioning Strategy: Lockstep

All three npm packages share the same version number, always. The Ruby gem version tracks independently (it already has its own versioning).

**Rules:**

1. **Same version, always.** When any package is released, all three are released at the same version. If a release only changes core, the supplemental packages still get the version bump.
2. **Patch-tolerant direct dep on core.** `shakapacker-webpack` and `shakapacker-rspack` declare `"shakapacker": "~10.1.0"` as a direct dependency (it is the wrapper's whole reason to exist; not a singleton). This pins the supplemental packages to the exact minor of core they were tested against — a user on `shakapacker@10.2.x` must also upgrade their supplemental package to a `10.2.x` release. Patch flexibility is preserved (`10.1.0`–`10.1.x` all satisfy the range). Caret (`^10.1.0`) was rejected because it would allow `shakapacker@10.2.0` + `shakapacker-webpack@10.1.0`, an untested combination that defeats the lockstep value proposition. (Bundler singletons like `webpack` use caret peer dependencies — different rule, different reason.)
3. **Start at v10.1.0.** All three packages begin at the same version. No separate versioning at any point.
4. **Defer workspace tooling until the root can be private.** During Phase 1, the root `package.json` remains the publishable core package, so root workspaces are not enabled under Yarn Classic.

**Why lockstep:**

- The supplemental packages are tightly coupled to core — independent versioning would create a compatibility matrix nightmare.
- Precedent: Next.js (`next`, `@next/env`, `@next/swc-*`), Angular (`@angular/core`, `@angular/compiler`, etc.), and Babel (`@babel/core`, `@babel/preset-env`, etc.) all use lockstep versioning across their package families.
- Users see `"shakapacker": "~10.2.0"` and `"shakapacker-webpack": "~10.2.0"` — easy to reason about compatibility.
- "Empty bumps" (a supplemental package gets a version bump with no code change) are a tiny cost compared to the coordination headache of independent versions.

**Initial v10.1.0 release process:**

> **Sequencing is load-bearing.** Both supplemental packages declare `"shakapacker": "~10.1.0"` as a direct dependency, and `shakapacker-webpack` also declares `"terser-webpack-plugin"` as a direct dependency (resolved against the npm registry). Core `shakapacker` 10.1.0 must be published _before_ either supplemental, otherwise installers cannot resolve the dep.

```bash
# Releases the gem AND all three npm packages. The rake task bumps every
# package.json to the target version, commits + tags + pushes via release-it,
# then invokes scripts/publish-packages.sh to publish all three to npm in
# lockstep (core first, then supplementals).
bundle exec rake "release[10.1.0]"
```

Under the hood, the rake task:

1. Bumps `lib/shakapacker/version.rb` (`gem bump`).
2. Runs `npm version <v> --no-git-tag-version` in `packages/shakapacker-webpack` and `packages/shakapacker-rspack`, then rewrites their `dependencies.shakapacker` constraint to `~<v>` so a minor/major bump (e.g. `10.1.0` → `10.2.0`) doesn't ship supplementals declaring a stale `~10.1.0` core dep that cannot resolve `10.2.0`.
3. Invokes `release-it` with `--no-npm.publish` so it handles the core version bump, commit, tag, and push — but defers npm publishing.
4. Calls `./scripts/publish-packages.sh`, which re-validates lockstep across all three `package.json` files (both `version` AND each supplemental's `dependencies.shakapacker`) and publishes them in the required core-first order. Pre-release versions (e.g. `10.1.0-beta.1`) automatically get the matching `--tag` (`beta`, `rc`, etc.).
5. Runs `gem release` for RubyGems and syncs the GitHub release from `CHANGELOG.md`.

> **Why npm for publishing despite Yarn 1 for development.** The project pins `packageManager: yarn@1.22.22` and uses Yarn for all development scripts, but Yarn Classic does not have a workspace-aware publish command (and `yarn workspaces version` is not available in v1). We invoke `npm publish` per package directly until v11 picks a dedicated release tool — see Open Question #5.

For later Phase 1 releases, the same `rake "release[<version>]"` invocation handles all three packages. A dedicated workspace or release tool remains an open question for v11, when the core package can move under `packages/shakapacker/` and the repository root can become private.

The existing `bundle exec rake update_changelog` task should be updated to handle the monorepo structure, noting which packages were affected in each release.

### Ruby gemspec (v11.0.0)

| Dependency              | Current    | v11 Proposed | Reason                                                                                                                                                                                  |
| ----------------------- | ---------- | ------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `required_ruby_version` | `>= 2.7.0` | `>= 3.4.0`   | Ruby 3.1 (EOL 2025-03-26) and 3.2 (EOL 2026-04-01) are EOL; Ruby 3.3 (EOL 2027-03-31) leaves little headroom for v11. Ruby 3.4 (EOL ~2027-12) gives v11 a longer active-support window. |
| `activesupport`         | `>= 5.2`   | `>= 7.2`     | Rails 7.0/7.1 are unsupported (only 7.2.x, 8.0.x, 8.1.x receive security fixes)                                                                                                         |
| `railties`              | `>= 5.2`   | `>= 7.2`     | Match activesupport                                                                                                                                                                     |

**Ruby 3.3 was considered and rejected.** Setting `>= 3.3` would still drop the clearly-EOL 3.1 and 3.2, and would give Ruby 3.3 users a longer migration window. It was rejected because Ruby 3.3's EOL is 2027-03-31, only ~5 months after a likely v11 GA in late 2026 — meaning v11 would land already supporting an EOL Ruby. Choosing 3.4 aligns the support window with the v11 active-support lifetime. If user data shows a meaningful population still on 3.3 at v11 release time, this can be relaxed.

### Node.js engines

Core `shakapacker` was tightened to `^20.19.0 || >=22.12.0` in v10.1 (PR #1099, driven by `@rspack/core` 2.0.x). Supplemental packages must not declare a more permissive `engines.node` than core, because a user who satisfies the supplemental's range but not core's would pass the supplemental's install gate and then hit core's engine error. Both supplementals therefore mirror core:

| Package             | Node engine               | Reason                                                                           |
| ------------------- | ------------------------- | -------------------------------------------------------------------------------- |
| shakapacker-webpack | `^20.19.0 \|\| >=22.12.0` | Mirror of core's `engines.node`; cannot be more permissive than core             |
| shakapacker-rspack  | `^20.19.0 \|\| >=22.12.0` | Required by `@rspack/core` 2.0.1; same as core's range, so no further tightening |

### Installer Changes

The `shakapacker:install` rake task should be updated to:

1. Ask which bundler (webpack or rspack) — **default: rspack** (the non-interactive installer already defaults to rspack; the interactive prompt remains v11 work). Rspack ships SWC transpilation built in, so the recommended path is the lowest-friction install.
2. **If the user picked webpack**, ask which transpiler (swc, babel, esbuild, none) — default: swc. **Skip this question entirely for rspack** — rspack uses its built-in SWC and we don't want to expand the support burden by exposing transpiler swap-out for rspack users who don't need it.
3. Install the appropriate `shakapacker-*` package + its required bundler peers (npm 7+ could auto-install the peers, but the installer writes them explicitly for cross-PM consistency and for pnpm/Yarn PnP app-level imports)
4. Install **only** the optional peer dependencies for the features the app actually uses

## Migration Path

### v10.x → v10.1.0 (shipped)

User-facing migration steps live in [`docs/migration/v10.1-supplemental-packages.md`](migration/v10.1-supplemental-packages.md). Adoption is opt-in; nothing breaks for users who don't change anything.

### v10.x → v11.0.0 (planned, no firm date)

When v11 lands, the migration path will look roughly like:

- **Webpack and rspack users on the managed build path** adopt the matching supplemental package (or rely on v10.1 adoption already done) and update any stale loader/plugin versions to the pins enforced by the wrapper.
- **Custom-build users** (apps that output their own `manifest.json`) keep using bare `shakapacker` — no supplemental package needed.
- **Babel users** can stay on Babel but `babel-loader` will be v9+ only. Migration to SWC is recommended for build speed; see [`docs/transpiler-migration.md`](transpiler-migration.md).

The exact list of dropped versions and the Ruby/Rails floor will be confirmed once v11 has a release target. The driving factors are EOL dates for the runtimes we still support and adoption signal from the v10.1 supplemental packages.

## Alternatives Considered

### Single package with all optional peer deps (current approach)

The status quo. Rejected because:

- `package.json` cannot express "required if you chose webpack" — deps are either optional or required for everyone
- 23 optional peer deps provide no guardrails for new users
- Silenced warnings (`peerDependenciesMeta: optional`) don't help users make correct choices

### Single package with required peer deps for the default bundler

Rejected because it would force webpack dependencies on rspack users and vice versa, bloating everyone's dependency tree.

### Bundle webpack/rspack as a regular dependency (Next.js model)

Rejected because:

- Shakapacker supports **both** webpack and rspack — we can't bundle both
- Users need direct access to webpack/rspack for custom config files
- Vendoring would make it harder for users to apply webpack security patches independently

### Separate repos for supplemental packages

Rejected because:

- Core changes almost always affect both supplemental packages — separate repos mean cross-repo PRs for routine changes
- Testing a core change against both supplemental packages requires coordination across repos
- More CI pipelines to maintain, more places for things to drift out of sync
- Independent versioning creates a compatibility matrix problem that lockstep avoids
- The supplemental packages are too thin (mostly `package.json` + re-exports) to justify standalone repos

### Full monorepo split (separate gem per bundler)

Rejected because:

- The Ruby gem logic is shared across both bundlers
- Would double our release/maintenance burden on the gem side
- The npm-only split achieves the same dependency isolation without touching the gem

### Big bang v11 (no phased rollout)

Rejected because:

- v10 just shipped — bumping to v11 immediately feels rushed
- Phased rollout lets supplemental packages get real-world usage before they become required
- v10.1 is zero-risk for existing users

## Resolved Decisions

- **Package naming**: `shakapacker-webpack` / `shakapacker-rspack` (unscoped)
- **Repo structure**: Monorepo in existing `shakacode/shakapacker` repo, all packages under `packages/`
- **Versioning**: Lockstep — all three npm packages share the same version number
- **Rollout**: Phased — v10.1.0 (additive), v11.0.0 (breaking)
- **Supplemental dependency policy**: bundler singletons (`webpack`, `@rspack/core`, etc.) as required peer dependencies with caret ranges aligned to main `shakapacker`'s peer ranges; `shakapacker` itself as a tilde-pinned direct dependency for lockstep release coupling. Updated from the v10.1.0-rc.1 shape (tilde across the board, singletons as direct deps) after [issue #1131](https://github.com/shakacode/shakapacker/issues/1131).

## References

- [Community discussion](https://github.com/shakacode/shakapacker/issues/1030) — feedback that shaped this RFC
- [Current peer-dependencies docs](peer-dependencies.md)
- [Current optional-peer-dependencies docs](optional-peer-dependencies.md)
- [Next.js package.json](https://github.com/vercel/next.js/blob/canary/packages/next/package.json) — 4 peer deps, webpack vendored
- [Vite package.json](https://github.com/vitejs/vite/blob/main/packages/vite/package.json) — 5 deps, 12 optional peers
- [Transpiler migration guide](transpiler-migration.md)
