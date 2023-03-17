# Upgrading from Shakapacker v6 to v7

There will be several substantial and breaking changes in Shakapacker v7 that you need to manually account for when coming from Shakapacker v6. Shakapacker v6.7.0 provides backward compatibility for these changes, helping developers to have a smooth transition to version 7. This guide will help you through it.

## Usages of "webpacker" should now be "shakapacker"

Shakapacker v6 kept the 'webpacker' spelling. As a result, many config filenames, environment variables, rake tasks, etc., used the 'webpacker' spelling. Shakapacker 7 requires renaming to the 'shakapacker' spelling.

- `config/webpacker.yml` renames to `config/shakapacker.yml`
- `webpacker_precompile?` entry in the config file renames to `shakapacker_precompile?`
- `bin/webpacker` and `bin/webpacker-dev-server` rename to `bin/shakapacker` and `bin/shakapacker-dev-server`
- All environment variables in the format of `WEBPACKER_XYZ` rename to `SHAKAPACKER_XYZ`
- Options like `--debug-webpacker` rename to `--debug-shakapacker`
- Any `require "webpacker[/xyz]"` should be replaced with `require "shakapacker[/xyz]"`.

## Upgrade Steps

As mentioned above, Shakapacker 6.7.0 provides backward compatibility for the breaking changes in Shakapacker version 7. This helps the developers to have a smooth experience in making the required transition to the new requirements. To this end, follow these steps:

### Upgrade to 6.7.0

Before upgrading to version 7, upgrade Shakapacker to the latest 6.x version. You should have no issue running your application. However, you will see many deprecation messages. Once you've updated your app to clear the deprecation messages, then you should update to v7.

#### Ruby Usage

- Rename constant `Webpacker` to `Shakapacker`.
- Rename`Shakapacker.config.webpacker_precompile?` method, replace it with `Shakapacker.config.shakapacker_precompile?`

#### `webpacker.yml` renamed and updated

- Rename `config/shakapacker.yml` to `config/webpacker.yml`.
- Change `webpacker_precompile` entry to `shakapacker_precompile` if it exists in the config file.

#### Binstubs

- Run `rake shakapacker:binstubs` to get the new files in place. and delete the old webpacker ones.
- Alternatively, if you have updated these files manually, rename `bin/webpacker` and `bin/webpacker-dev-server` to `bin/shakapacker` and `bin/shakapacker-dev-server`, and update the content of these files to change 'webpacker' to 'shakapacker'.

### Binstub Options

- `--debug-webpacker` is now `--debug-shakapacker` for your shakpacker binstubs.

#### Environment variables

- Rename environment variables in the format of `WEBPACKER_XYZ` to `SHAKAPACKER_XYZ`.

### Upgrade to v7

Once you have successfully upgraded to version 6.x and have no deprecation messages in your console, you should be ready to upgrade Shakapacker to version 7. Check the [CHANGELOG](../CHANGELOG.md) for additional details.