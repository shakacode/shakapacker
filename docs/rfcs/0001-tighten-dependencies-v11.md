# RFC: Tighten Dependencies with Supplemental Packages

**Status:** Draft (Rev 6 — phased rollout v10.1 / v11)
**Date:** 2026-03-28 (revised 2026-05-02)
**Author:** Justin Gordon

## Summary

Shakapacker should split into **three npm packages** to cleanly separate concerns:

1. **`shakapacker`** — core package (config loading, manifest reading, dev server proxy, CLI). Zero bundler-specific peer deps.
2. **`shakapacker-webpack`** — managed webpack build. Has `webpack`, `webpack-cli`, etc. as **required** peer deps.
3. **`shakapacker-rspack`** — managed rspack build. Has `@rspack/core`, `@rspack/cli`, etc. as **required** peer deps.

This is rolled out in two phases:

- **v10.1.0** (non-breaking) — restructure repo, publish supplemental packages as additive. Existing peer deps remain in core. Supplemental packages pin the managed dependency stack to known-current versions. Users can adopt early.
- **v11.0.0** (breaking) — remove bundler peer deps from core, tighten version ranges, drop EOL runtimes. Supplemental packages become required.

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

Add the two supplemental packages. **No changes to the core `shakapacker` package's peer deps.** Existing users are unaffected. The new supplemental packages take the stricter path: exact peer pins for the managed webpack/rspack stack so compatibility is explicit and updated with each Shakapacker package release.

What ships:

- Create `packages/shakapacker-webpack/` and `packages/shakapacker-rspack/`
- Core `package/` directory stays in place (NOT moved to `packages/shakapacker/`)
- Do not enable root `workspaces` yet: the root `package.json` is also the publishable `shakapacker` package, and Yarn Classic requires workspace roots to be `private: true`
- Publish core `shakapacker` 10.1.0 first, then publish supplemental packages at v10.1.0 so their core peer deps resolve
- Update docs and installer to recommend the new pattern for new projects
- Core `shakapacker` still declares all existing peer deps (nothing removed)
- Supplemental packages use exact peer pins for managed dependencies, rather than inheriting the broad optional ranges from core

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

**Peer dependencies (required):**

| Package                 | Version   |
| ----------------------- | --------- |
| shakapacker             | `^10.1.0` |
| webpack                 | `5.106.2` |
| webpack-cli             | `7.0.2`   |
| webpack-assets-manifest | `6.5.1`   |

**Peer dependencies (optional):**

| Package                              | Version  | When needed             |
| ------------------------------------ | -------- | ----------------------- |
| webpack-dev-server                   | `5.2.3`  | Dev mode with HMR       |
| mini-css-extract-plugin              | `2.10.2` | CSS extraction          |
| terser-webpack-plugin                | `5.5.0`  | Production minification |
| webpack-subresource-integrity        | `5.1.0`  | SRI hashes              |
| @pmmmwh/react-refresh-webpack-plugin | `0.6.2`  | React HMR               |

**Peer dependencies (optional — transpiler, pick one):**

| Package        | Version   | When needed                              |
| -------------- | --------- | ---------------------------------------- |
| @swc/core      | `1.15.33` | `javascript_transpiler: "swc"` (default) |
| swc-loader     | `0.2.7`   | Paired with @swc/core                    |
| @babel/core    | `7.29.0`  | `javascript_transpiler: "babel"`         |
| babel-loader   | `10.1.1`  | Paired with @babel/core                  |
| esbuild        | `0.28.0`  | `javascript_transpiler: "esbuild"`       |
| esbuild-loader | `4.4.3`   | Paired with esbuild                      |

**Peer dependencies (optional — CSS preprocessors):**

| Package     | Version  | When needed      |
| ----------- | -------- | ---------------- |
| css-loader  | `7.1.4`  | CSS processing   |
| sass        | `1.99.0` | SCSS/Sass files  |
| sass-loader | `16.0.7` | Paired with sass |

#### `shakapacker-rspack` (managed rspack build)

Supplemental package for the rspack managed build experience.

**Peer dependencies (required):**

| Package                | Version   |
| ---------------------- | --------- |
| shakapacker            | `^10.1.0` |
| @rspack/core           | `2.0.1`   |
| @rspack/cli            | `2.0.1`   |
| rspack-manifest-plugin | `5.2.1`   |

**Peer dependencies (optional):**

| Package                      | Version  | When needed      |
| ---------------------------- | -------- | ---------------- |
| @rspack/plugin-react-refresh | `2.0.0`  | React HMR        |
| css-loader                   | `7.1.4`  | CSS processing   |
| sass                         | `1.99.0` | SCSS/Sass files  |
| sass-loader                  | `16.0.7` | Paired with sass |

Note: rspack has built-in SWC transpilation, so no external transpiler deps are needed.

Rspack v2 is stable, so the supplemental rspack package pins to the current v2 GA line. Older Rspack v1 and v2 pre-releases remain allowed only through the legacy optional peer ranges in core `shakapacker` during the v10.x compatibility window.

### Version Pinning Philosophy

The core `shakapacker` package keeps its broad optional peer ranges during v10.x so existing applications are not broken by an additive release. The supplemental packages use a different policy:

- **Pin managed peer dependencies exactly.** `shakapacker-webpack` and `shakapacker-rspack` declare the dependency set Shakapacker is expected to work with today, not every historical version that might still work.
- **Update pins with Shakapacker package releases.** When webpack, Rspack, loaders, or managed plugins move, release a new lockstep Shakapacker package version with updated peer pins.
- **Keep the maintenance signal honest.** A version outside the supplemental package pins is not claimed as supported until the pins are updated.
- **Avoid pre-release pins unless deliberately testing a pre-release line.** For example, `webpack-subresource-integrity` stays on the latest stable 5.1.x release even though its npm `latest` dist-tag currently points at a release candidate.

### What Each User Type Installs (v11+)

**Webpack + SWC (default happy path):**

```json
{
  "devDependencies": {
    "shakapacker": "^11.0.0",
    "shakapacker-webpack": "^11.0.0",
    "webpack": "5.106.2",
    "webpack-cli": "7.0.2",
    "webpack-assets-manifest": "6.5.1",
    "webpack-dev-server": "5.2.3",
    "@swc/core": "1.15.33",
    "swc-loader": "0.2.7",
    "css-loader": "7.1.4",
    "mini-css-extract-plugin": "2.10.2"
  }
}
```

**Rspack (SWC is built-in):**

```json
{
  "devDependencies": {
    "shakapacker": "^11.0.0",
    "shakapacker-rspack": "^11.0.0",
    "@rspack/core": "2.0.1",
    "@rspack/cli": "2.0.1",
    "rspack-manifest-plugin": "5.2.1",
    "css-loader": "7.1.4"
  }
}
```

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
2. **Caret peer dep on core.** `shakapacker-webpack` and `shakapacker-rspack` declare `"shakapacker": "^10.1.0"` as a peer dep. This means minor bumps don't force users to update all packages on the same day, but they stay within the same major.
3. **Start at v10.1.0.** All three packages begin at the same version. No separate versioning at any point.
4. **Defer workspace tooling until the root can be private.** During Phase 1, the root `package.json` remains the publishable core package, so root workspaces are not enabled under Yarn Classic.

**Why lockstep:**

- The supplemental packages are tightly coupled to core — independent versioning would create a compatibility matrix nightmare.
- Precedent: Next.js (`next`, `@next/env`, `@next/swc-*`), Angular (`@angular/core`, `@angular/compiler`, etc.), and Babel (`@babel/core`, `@babel/preset-env`, etc.) all use lockstep versioning across their package families.
- Users see `"shakapacker": "^10.2.0"` and `"shakapacker-webpack": "^10.2.0"` — easy to reason about compatibility.
- "Empty bumps" (a supplemental package gets a version bump with no code change) are a tiny cost compared to the coordination headache of independent versions.

**Initial v10.1.0 release process:**

> **Sequencing is load-bearing.** Both supplemental packages declare `"shakapacker": "^10.1.0"` as a required peer dep. Core `shakapacker` 10.1.0 must be published _before_ either supplemental, otherwise installers receive an unresolvable peer dependency error.

```bash
# Bump the existing root package from 10.0.0 to 10.1.0.
npm version 10.1.0 --no-git-tag-version
# Bump the supplemental packages to the same version (lockstep).
(cd packages/shakapacker-webpack && npm version 10.1.0 --no-git-tag-version)
(cd packages/shakapacker-rspack && npm version 10.1.0 --no-git-tag-version)

# Publish all three in the required order (core first, then supplementals).
# The script verifies version lockstep before publishing anything.
./scripts/publish-packages.sh

# Ruby gem is released separately via existing rake task
bundle exec rake release
```

> **Why npm for publishing despite Yarn 1 for development.** The project pins `packageManager: yarn@1.22.22` and uses Yarn for all development scripts, but Yarn Classic does not have a workspace-aware publish command (and `yarn workspaces version` is not available in v1). We invoke `npm publish` per package directly until v11 picks a dedicated release tool — see Open Question #5.

For later Phase 1 releases, bump all three package manifests to the same version in one release commit before publishing. A dedicated workspace or release tool remains an open question for v11, when the core package can move under `packages/shakapacker/` and the repository root can become private.

The existing `bundle exec rake update_changelog` task should be updated to handle the monorepo structure, noting which packages were affected in each release.

### Ruby gemspec (v11.0.0)

| Dependency              | Current    | v11 Proposed | Reason                                                                                                                                                                                  |
| ----------------------- | ---------- | ------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `required_ruby_version` | `>= 2.7.0` | `>= 3.4.0`   | Ruby 3.1 (EOL 2025-03-26) and 3.2 (EOL 2026-04-01) are EOL; Ruby 3.3 (EOL 2027-03-31) leaves little headroom for v11. Ruby 3.4 (EOL ~2027-12) gives v11 a longer active-support window. |
| `activesupport`         | `>= 5.2`   | `>= 7.2`     | Rails 7.0/7.1 are unsupported (only 7.2.x, 8.0.x, 8.1.x receive security fixes)                                                                                                         |
| `railties`              | `>= 5.2`   | `>= 7.2`     | Match activesupport                                                                                                                                                                     |

**Ruby 3.3 was considered and rejected.** Setting `>= 3.3` would still drop the clearly-EOL 3.1 and 3.2, and would give Ruby 3.3 users a longer migration window. It was rejected because Ruby 3.3's EOL is 2027-03-31, only ~5 months after a likely v11 GA in late 2026 — meaning v11 would land already supporting an EOL Ruby. Choosing 3.4 aligns the support window with the v11 active-support lifetime. If user data shows a meaningful population still on 3.3 at v11 release time, this can be relaxed.

### Node.js engines

Core `shakapacker` keeps `engines.node >= 20` during the v10.x compatibility window. Supplemental packages declare the stricter runtime required by their pinned managed stack:

| Package             | Node engine               | Reason                                               |
| ------------------- | ------------------------- | ---------------------------------------------------- |
| shakapacker-webpack | `>= 20.10.0`              | `webpack-assets-manifest` 6.5.1 requires Node 20.10+ |
| shakapacker-rspack  | `^20.19.0 \|\| >=22.12.0` | `@rspack/core` 2.0.1 requires this range             |

### Installer Changes

The `shakapacker:install` rake task should be updated to:

1. Ask which bundler (webpack or rspack) — default: webpack
2. Ask which transpiler (swc, babel, esbuild, none) — default: swc
3. Install `shakapacker` + the appropriate `shakapacker-*` package
4. Install **only** the required peer dependencies for the chosen combination

## Migration Path

### v10.x → v10.1.0 (Optional, Zero-Risk)

Existing users: nothing changes. Your current `package.json` continues to work.

New projects or early adopters:

1. Add `shakapacker-webpack` or `shakapacker-rspack` to devDependencies
2. Both the old pattern (peer deps on core) and new pattern (supplemental package) work simultaneously

### v10.x → v11.0.0 (Required)

#### For Webpack Users

1. Update `shakapacker` gem and npm package to v11
2. Add `shakapacker-webpack` to devDependencies (if not already from v10.1)
3. Update stale managed dependencies to the exact versions required by `shakapacker-webpack`
4. Remove `compression-webpack-plugin` if unused (no longer a peer dep)

#### For Rspack Users

1. Update `shakapacker` gem and npm package to v11
2. Add `shakapacker-rspack` to devDependencies (if not already from v10.1)
3. Update `@rspack/core` and `@rspack/cli` to the exact versions required by `shakapacker-rspack`
4. Remove any webpack-specific packages that were installed but unused

#### For Custom Build Users

1. Update `shakapacker` gem and npm package to v11
2. Do NOT install any `shakapacker-*` supplemental package
3. Remove any Shakapacker peer deps you installed but don't directly use
4. Ensure your custom build outputs `manifest.json` in the configured location

#### For Babel Users

Babel is no longer the default and hasn't been since v8. In v11:

- Babel still works, but only `babel-loader` v9+ is supported
- Consider migrating to SWC (`javascript_transpiler: "swc"`) for faster builds
- The transpiler migration guide already exists at `docs/transpiler-migration.md`

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

## Open Questions

1. **Should we provide a `shakapacker:upgrade` task** that automatically updates `package.json` dependencies for the v10 -> v11 migration?

2. **Should the `assets_bundler` config support `"custom"` or `"none"`** as an explicit value to make custom build mode clearer than setting `javascript_transpiler: "none"`?

3. **Should `compression-webpack-plugin` be documented** as a user-added plugin rather than removed silently?

4. **Future extensibility**: Could this pattern extend to community packages? e.g., `shakapacker-vite` contributed by the community for Vite integration, as suggested by G-Rath.

5. **Workspace tooling**: npm workspaces, yarn workspaces, or a dedicated tool like changesets/turborepo for the monorepo?

## References

- [Community discussion](https://github.com/shakacode/shakapacker/issues/1030) — feedback that shaped this RFC
- [Current peer-dependencies docs](../peer-dependencies.md)
- [Current optional-peer-dependencies docs](../optional-peer-dependencies.md)
- [Next.js package.json](https://github.com/vercel/next.js/blob/canary/packages/next/package.json) — 4 peer deps, webpack vendored
- [Vite package.json](https://github.com/vitejs/vite/blob/main/packages/vite/package.json) — 5 deps, 12 optional peers
- [Transpiler migration guide](../transpiler-migration.md)
