# Upgrading from Shakapacker v6 to v7

There are several substantial changes in Shakapacker v7 that you need to manually account for when coming from Shakapacker v6. This guide will help you through it.

## Use Shakapacker name in the entire project

Shakapacker v6 used the Webpacker module internally. As a result, it was using a Webpacker-like name for config files, environment variables, and command-line options. Since Shakapacker 7, all these cases are renamed to Shakapacker names. This includes but not limited to the following examples:

- `config/webpacker.yml` renamed to `config/shakapacker.yml`
- `webpacker_precompile?` entry in the config file is renamed to `shakapacker_precompile?`
- `bin/webpacker` and `bin/webpacker-dev-server` is renamed to `bin/shakapacker` and `bin/shakapacker-dev-server`
- All environment variables in the format of `WEBPACKER_XYZ` is renamed to `SHAKAPACKER_XYZ`
- Options like `--debug-webpacker` renamed to `--debug-shakapacker`

Also any `require "webpacker[/xyz]"` should be replaced with `require "shakapacker[/xyz]"`.
