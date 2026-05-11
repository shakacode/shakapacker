# Dependency Strategy

**Status:** v10.1 phase shipped (supplemental packages additive). v11 phase is the working roadmap, not a scheduled release.
**Original RFC date:** 2026-03-28 (revised 2026-05-10)
**Author:** Justin Gordon

> **Looking for the user-facing migration steps?** See [`docs/migration/v10.1-supplemental-packages.md`](migration/v10.1-supplemental-packages.md). This doc captures the design rationale, alternatives considered, and the v11 roadmap — read it if you want to understand _why_ the dependency surface looks the way it does.

## Summary

Shakapacker is split into **three npm packages** to cleanly separate concerns:

1. **`shakapacker`** — core package (config loading, manifest reading, dev server proxy, CLI). Zero bundler-specific peer deps.
2. **`shakapacker-webpack`** — managed webpack build. **Bundles `webpack`, `webpack-cli`, etc. as direct dependencies** so a single install brings the full stack.
3. **`shakapacker-rspack`** — managed rspack build. **Bundles `@rspack/core`, `@rspack/cli`, etc. as direct dependencies** so a single install brings the full stack.

The rollout is phased:

- **v10.1.0 (shipped, non-breaking)** — supplemental packages are published as additive. Existing peer deps remain in core. Adopters opt in whenever they're ready.
- **v11.0.0 (planned, no firm date)** — supplemental packages become required for managed builds; core no longer declares bundler peer deps. Older bundler/loader versions and EOL Ruby/Rails versions get dropped. Specifics are sketched in §"Phase 2" below but the timing depends on adoption signal from v10.1.

## Motivation

### The Current Problem

Shakapacker v10 has **23 optional peer dependencies** with extremely broad version ranges:

- `esbuild`: 14 separate version ranges (`^0.14.0 || ^0.15.0 || ... || ^0.27.0`)
- `webpack-cli`: 4 major versions (`^4.9.2 || ^5.0.0 || ^6.0.0 || ^7.0.0`)
- `sass-loader`: 4 major versions (`^13.0.0 || ^14.0.0 || ^15.0.0 || ^16.0.0`)
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

Add the two supplemental packages. **No changes to the core `shakapacker` package's peer deps.** Existing users who do not adopt a supplemental package are unaffected. Early adopters of the supplemental packages opt into their exact managed stack pins so compatibility is explicit and updated with each Shakapacker package release.

What ships:

- Create `packages/shakapacker-webpack/` and `packages/shakapacker-rspack/`
- Core `package/` directory stays in place (NOT moved to `packages/shakapacker/`)
- Do not enable root `workspaces` yet: the root `package.json` is also the publishable `shakapacker` package, and Yarn Classic requires workspace roots to be `private: true`
- Publish core `shakapacker` 10.1.0 first, then publish supplemental packages at v10.1.0 so their core peer deps resolve
- Update docs and installer to recommend the new pattern for new projects
- Core `shakapacker` still declares all existing peer deps (nothing removed)
- Supplemental packages use exact peer pins for managed dependencies, rather than inheriting the broad optional ranges from core
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

> The version columns below show the exact release Shakapacker tests against. `package.json` ships these as patch-tolerant `~X.Y.Z` ranges (see [Version Pinning Philosophy](#version-pinning-philosophy)) — e.g. `webpack` is enforced as `~5.106.2`, not pinned to `5.106.2`.

**Dependencies (bundled — installed automatically):**

| Package                 | Tested at |
| ----------------------- | --------- |
| shakapacker             | `~10.1.0` |
| webpack                 | `5.106.2` |
| webpack-cli             | `7.0.2`   |
| webpack-assets-manifest | `6.5.1`   |

The required managed-build stack ships as `dependencies` so a single `yarn add shakapacker-webpack` (or npm/pnpm equivalent) pulls in everything an app needs to start building. npm hoisting keeps a single instance of webpack at the top level so plugin `instanceof` checks behave correctly.

**Peer dependencies (optional):**

| Package                              | Tested at | When needed             |
| ------------------------------------ | --------- | ----------------------- |
| webpack-dev-server                   | `5.2.3`   | Dev mode with HMR       |
| mini-css-extract-plugin              | `2.10.2`  | CSS extraction          |
| terser-webpack-plugin                | `5.5.0`   | Production minification |
| webpack-subresource-integrity        | `5.1.0`   | SRI hashes              |
| @pmmmwh/react-refresh-webpack-plugin | `0.6.2`   | React HMR               |

**Peer dependencies (optional — transpiler, pick one):**

| Package        | Tested at | When needed                              |
| -------------- | --------- | ---------------------------------------- |
| @swc/core      | `1.15.33` | `javascript_transpiler: "swc"` (default) |
| swc-loader     | `0.2.7`   | Paired with @swc/core                    |
| @babel/core    | `7.29.0`  | `javascript_transpiler: "babel"`         |
| babel-loader   | `10.1.1`  | Paired with @babel/core                  |
| esbuild        | `0.27.7`  | `javascript_transpiler: "esbuild"`       |
| esbuild-loader | `4.4.3`   | Paired with esbuild                      |

**Peer dependencies (optional — CSS preprocessors):**

| Package     | Tested at | When needed      |
| ----------- | --------- | ---------------- |
| css-loader  | `7.1.4`   | CSS processing   |
| sass        | `1.99.0`  | SCSS/Sass files  |
| sass-loader | `16.0.7`  | Paired with sass |

#### `shakapacker-rspack` (managed rspack build)

Supplemental package for the rspack managed build experience.

**Dependencies (bundled — installed automatically):**

| Package                | Tested at |
| ---------------------- | --------- |
| shakapacker            | `~10.1.0` |
| @rspack/core           | `2.0.1`   |
| @rspack/cli            | `2.0.1`   |
| rspack-manifest-plugin | `5.2.1`   |

The required managed-build stack ships as `dependencies` so a single `yarn add shakapacker-rspack` (or npm/pnpm equivalent) pulls in everything an app needs to start building.

**Peer dependencies (optional):**

| Package                      | Tested at | When needed      |
| ---------------------------- | --------- | ---------------- |
| @rspack/plugin-react-refresh | `2.0.1`   | React HMR        |
| css-loader                   | `7.1.4`   | CSS processing   |
| sass                         | `1.99.0`  | SCSS/Sass files  |
| sass-loader                  | `16.0.7`  | Paired with sass |

Note: rspack has built-in SWC transpilation, so no external transpiler deps are needed.

Rspack v2 is stable, so the supplemental rspack package pins to the current v2 GA line. Older Rspack v1 and v2 pre-releases remain allowed only through the legacy optional peer ranges in core `shakapacker` during the v10.x compatibility window.

### Version Pinning Philosophy

The core `shakapacker` package keeps its broad optional peer ranges during v10.x so existing applications are not broken by an additive release. The supplemental packages use a different policy. The version numbers above are the versions Shakapacker is tested against; bundled `dependencies` and optional `peerDependencies` alike ship as patch-tolerant `~X.Y.Z` ranges so a consumer's routine patch bump does not trigger an npm 7+ peer-conflict warning until the next Shakapacker release.

- **Patch-tolerant pins (`~X.Y.Z`) for bundled deps and optional peers alike.** Patch releases are accepted across the managed stack — webpack, Rspack, loaders, transpilers, and CSS preprocessors. Major and minor bumps still wait for a coordinated Shakapacker release.
- **Update pins with Shakapacker package releases.** When webpack, Rspack, loaders, or managed plugins move, release a new lockstep Shakapacker package version with updated pins.
- **Keep the maintenance signal honest.** A version outside the supplemental package pins is not claimed as supported until the pins are updated.
- **Avoid pre-release pins unless deliberately testing a pre-release line.** For example, `webpack-subresource-integrity` stays on the latest stable 5.1.x release even though its npm `latest` dist-tag currently points at a release candidate.

### What Each User Type Installs (v11+)

The supplemental packages bundle the required managed-build stack as `dependencies`, so users only declare the wrapper and the optional feature peers they actually use.

**Webpack + SWC (default happy path):**

```json
{
  "devDependencies": {
    "shakapacker-webpack": "^11.0.0",
    "webpack-dev-server": "5.2.3",
    "@swc/core": "1.15.33",
    "swc-loader": "0.2.7",
    "css-loader": "7.1.4",
    "mini-css-extract-plugin": "2.10.2"
  }
}
```

`shakapacker`, `webpack`, `webpack-cli`, and `webpack-assets-manifest` come along automatically as deps of `shakapacker-webpack`.

**Rspack (SWC is built-in):**

```json
{
  "devDependencies": {
    "shakapacker-rspack": "^11.0.0",
    "css-loader": "7.1.4"
  }
}
```

`shakapacker`, `@rspack/core`, `@rspack/cli`, and `rspack-manifest-plugin` come along automatically as deps of `shakapacker-rspack`.

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
2. **Patch-tolerant peer dep on core.** `shakapacker-webpack` and `shakapacker-rspack` declare `"shakapacker": "~10.1.0"` as a peer dep. This pins the supplemental packages to the exact minor of core they were tested against — a user on `shakapacker@10.2.x` must also upgrade their supplemental package to a `10.2.x` release. Patch flexibility is preserved (`10.1.0`–`10.1.x` all satisfy the range). Caret (`^10.1.0`) was rejected because it would allow `shakapacker@10.2.0` + `shakapacker-webpack@10.1.0`, an untested combination that defeats the lockstep value proposition.
3. **Start at v10.1.0.** All three packages begin at the same version. No separate versioning at any point.
4. **Defer workspace tooling until the root can be private.** During Phase 1, the root `package.json` remains the publishable core package, so root workspaces are not enabled under Yarn Classic.

**Why lockstep:**

- The supplemental packages are tightly coupled to core — independent versioning would create a compatibility matrix nightmare.
- Precedent: Next.js (`next`, `@next/env`, `@next/swc-*`), Angular (`@angular/core`, `@angular/compiler`, etc.), and Babel (`@babel/core`, `@babel/preset-env`, etc.) all use lockstep versioning across their package families.
- Users see `"shakapacker": "~10.2.0"` and `"shakapacker-webpack": "~10.2.0"` — easy to reason about compatibility.
- "Empty bumps" (a supplemental package gets a version bump with no code change) are a tiny cost compared to the coordination headache of independent versions.

**Initial v10.1.0 release process:**

> **Sequencing is load-bearing.** Both supplemental packages declare `"shakapacker": "~10.1.0"` as a direct dependency. Core `shakapacker` 10.1.0 must be published _before_ either supplemental, otherwise installers cannot resolve the dep.

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

1. Ask which bundler (webpack or rspack) — **default: rspack**. Rspack ships SWC transpilation built in, so the recommended path is the lowest-friction install.
2. **If the user picked webpack**, ask which transpiler (swc, babel, esbuild, none) — default: swc. **Skip this question entirely for rspack** — rspack uses its built-in SWC and we don't want to expand the support burden by exposing transpiler swap-out for rspack users who don't need it.
3. Install the appropriate `shakapacker-*` package (it bundles `shakapacker` and the bundler stack)
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
- **Supplemental dependency policy**: exact peer pins for managed stacks; update pins through lockstep Shakapacker package releases

## References

- [Community discussion](https://github.com/shakacode/shakapacker/issues/1030) — feedback that shaped this RFC
- [Current peer-dependencies docs](peer-dependencies.md)
- [Current optional-peer-dependencies docs](optional-peer-dependencies.md)
- [Next.js package.json](https://github.com/vercel/next.js/blob/canary/packages/next/package.json) — 4 peer deps, webpack vendored
- [Vite package.json](https://github.com/vitejs/vite/blob/main/packages/vite/package.json) — 5 deps, 12 optional peers
- [Transpiler migration guide](transpiler-migration.md)
