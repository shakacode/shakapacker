# Installation

This guide covers the standard Shakapacker install flow for Rails apps. For
configuration details after installation, see the [configuration guide](./configuration.md).

## Prerequisites

- Ruby 2.7+
- Rails 5.2+
- Node.js 20+
- A JavaScript package manager supported by
  [`package_json`](https://github.com/shakacode/package_json): npm, Yarn,
  pnpm, or Bun

For new Rails 6+ apps, skip Rails' default JavaScript installer so Shakapacker
can create the bundler files:

```bash
rails new myapp --skip-javascript
cd myapp
```

## Add the Gem

Add Shakapacker to your app:

```bash
bundle add shakapacker --strict
```

Then install bundle dependencies:

```bash
./bin/bundle install
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
conflict with existing files, choose one of these modes:

```bash
# Prompt before overwriting conflicting files
bundle exec rake shakapacker:install

# Overwrite generated files without prompting
FORCE=true bundle exec rake shakapacker:install

# Keep existing files and create only missing generated files
SKIP=true bundle exec rake shakapacker:install
```

Accepted truthy values for `FORCE` and `SKIP` are `true`, `1`, and `yes`
case-insensitively. If both are set, `FORCE` wins.

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

New installs use webpack and SWC by default. To install with Rspack:

```bash
SHAKAPACKER_ASSETS_BUNDLER=rspack bundle exec rake shakapacker:install
```

To install with Babel instead of SWC:

```bash
JAVASCRIPT_TRANSPILER=babel bundle exec rake shakapacker:install
```

Most JavaScript packages are optional peer dependencies. The installer adds the
subset needed for your selected bundler/transpiler setup.

See:

- [Optional peer dependencies](./optional-peer-dependencies.md)
- [Current peer dependency ranges](./peer-dependencies.md)
- [Rspack migration guide](./rspack_migration_guide.md)
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

Then add the generated files to version control.

## Next Steps

- Review [configuration options](./configuration.md)
- Add [React](./react.md) or [TypeScript](./typescript.md)
- Configure [deployment](./deployment.md)
- Troubleshoot with [`shakapacker:doctor`](./troubleshooting.md)
