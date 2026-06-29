# Installation

This guide covers the standard Shakapacker install flow for Rails apps. For
configuration details after installation, see the [configuration guide](./configuration.md).

## Prerequisites

- Ruby 2.7+
- Rails 5.2+
- Node.js `^20.19.0` or `>=22.12.0` (see
  [`package.json` engines](../package.json))
- A JavaScript package manager supported by
  [`package_json`](https://github.com/shakacode/package_json): npm, Yarn,
  pnpm, or Bun

## Add the Gem

### New Rails App

#### Rails v6+

For a new Rails 6+ app, skip Rails' default JavaScript installer so
Shakapacker can create the bundler files, then continue from the app root:

```bash
rails new myapp --skip-javascript
cd myapp
bundle add shakapacker --strict
```

### Existing Rails App

For an existing Rails app (5.2+), start from the app root and skip the
`rails new` step.

```bash
bundle add shakapacker --strict
```

## Run the Installer

Run the Shakapacker installer from the Rails app root:

```bash
bundle exec rake shakapacker:install
```

The installer creates the default Shakapacker configuration, JavaScript entry
point, bundler config, binstubs, and package dependencies for the selected
bundler/transpiler setup.

Before running the installer, commit or stash local work. If generated files
conflict with existing files, the default install prompts before overwriting.
To choose non-interactive conflict handling, use one of these modes:

```bash
# Overwrite generated files without prompting
FORCE=true bundle exec rake shakapacker:install

# Keep existing files and create only missing generated files
SKIP=true bundle exec rake shakapacker:install
```

Accepted truthy values for `FORCE` and `SKIP` are `true`, `1`, and `yes`
case-insensitively. If both are set, `FORCE` wins.

### Optional: Consolidate dev dependencies with a supplemental package (10.1+)

The installer adds the managed-build stack to `package.json` as individual
entries (`shakapacker`, `webpack`, `webpack-cli`, `webpack-assets-manifest` for
webpack apps; `shakapacker`, `@rspack/core`, `@rspack/cli`,
`@rspack/dev-server`, `rspack-manifest-plugin` for rspack apps). On Shakapacker 10.1+ you can
optionally replace those entries with a single
[`shakapacker-webpack`](../packages/shakapacker-webpack/README.md) or
[`shakapacker-rspack`](../packages/shakapacker-rspack/README.md) dependency.
The supplemental package pulls in the same managed stack at the exact tested
versions and has no runtime impact — adoption is opt-in. See the
[v10.1 supplemental packages migration guide](./migration/v10.1-supplemental-packages.md)
for the before/after.

## Package Manager Selection

Shakapacker uses the
[`package_json`](https://github.com/shakacode/package_json) gem to update
`package.json` and run the app's package manager. Selection is based on the
`packageManager` field in `package.json`.

If `packageManager` is missing, `shakapacker:install` infers it from the lock
file and the package manager version. Without a lock file, it defaults to npm
unless `PACKAGE_JSON_FALLBACK_MANAGER` is set:

```bash
PACKAGE_JSON_FALLBACK_MANAGER=yarn bundle exec rake shakapacker:install
PACKAGE_JSON_FALLBACK_MANAGER=pnpm bundle exec rake shakapacker:install
PACKAGE_JSON_FALLBACK_MANAGER=bun bundle exec rake shakapacker:install
```

The `packageManager` field selects the package manager command. Shakapacker does
not install the package manager or enforce that exact version. Use Corepack or
your preferred toolchain setup to install npm, Yarn, pnpm, or Bun before running
the installer.

If you use Yarn PnP, configure Babel with `babel.config.js` rather than a Babel
config inside `package.json`. See
[customizing Babel config](./customizing_babel_config.md).

## Choosing a Bundler or Transpiler

New installs use Rspack by default. To install with Webpack:

```bash
SHAKAPACKER_ASSETS_BUNDLER=webpack bundle exec rake shakapacker:install
# or (quote the task name so zsh does not treat the brackets as a glob)
bundle exec rake 'shakapacker:install[webpack]'
```

To install with Babel instead of SWC (applies to webpack installs — Rspack always
uses its built-in SWC and ignores `javascript_transpiler`):

```bash
SHAKAPACKER_ASSETS_BUNDLER=webpack JAVASCRIPT_TRANSPILER=babel bundle exec rake shakapacker:install
```

Most JavaScript packages are optional peer dependencies. The installer adds the
subset needed for your selected bundler/transpiler setup.

See:

- [Optional peer dependencies](./optional-peer-dependencies.md)
- [Current peer dependency ranges](./peer-dependencies.md)
- [Rspack guide](./rspack.md)
- [Rspack migration guide (webpack to Rspack)](./rspack_migration_guide.md)
- [Transpiler migration guide](./transpiler-migration.md)

## Verify the Install

After installation, verify the generated config and build:

```bash
bundle exec rake shakapacker:verify_install
bin/shakapacker
```

For development with the dev server:

```bash
bin/shakapacker-dev-server
```

Then add the generated files to version control, including
`config/shakapacker.yml`, `config/webpack/` or `config/rspack/`,
`bin/shakapacker`, `bin/shakapacker-dev-server`, and the
`app/javascript/packs/application.js` entry point.

## Next Steps

- Review [configuration options](./configuration.md)
- Add [React](./react.md) or [TypeScript](./typescript.md)
- Configure [deployment](./deployment.md)
- Troubleshoot common install issues in the
  [troubleshooting guide](./troubleshooting.md)
