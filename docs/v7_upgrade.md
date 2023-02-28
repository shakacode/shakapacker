# Upgrading from Shakapacker v6 to v7

There will be several substantial and breaking changes in Shakapacker v7 that you need to manually account for when coming from Shakapacker v6. Shakapacker v6.6.x provides backward compatibility for these changes, helping developers to have a smooth transition to version 7. This guide will help you through it.

## No Webpacker anymore

Shakapacker v6 used a fork of the Webpacker module internally. As a result, in many cases including config filename, environment variables, rake tasks,... we were using Webpacker name. Starting from Shakapacker 7, all these cases are renamed to Shakapacker.

- `config/webpacker.yml` renames to `config/shakapacker.yml`
- `webpacker_precompile?` entry in the config file renames to `shakapacker_precompile?`
- `bin/webpacker` and `bin/webpacker-dev-server` rename to `bin/shakapacker` and `bin/shakapacker-dev-server`
- All environment variables in the format of `WEBPACKER_XYZ` rename to `SHAKAPACKER_XYZ`
- Options like `--debug-webpacker` rename to `--debug-shakapacker`
- Any `require "webpacker[/xyz]"` should be replaced with `require "shakapacker[/xyz]"`.

## Upgrade Steps

As mentioned above, Shakapacker 6.6.x provides backward compatibility for the breaking changes in Shakapacker version 7. This helps the developers to have a smooth experience in making the required transition to the new requirements. To this end, follow these steps:

### Upgrade to 6.6.x

Before upgrading to version 7 (future major release), make sure you upgrade your Shakapacker to the latest 6.6.x version. With the help of backward compatibility, you should have no issue running your application. Yet, you will receive several deprecation messages for the deprecated files, configuration, etc you use in your application.

#### Module
- Consider requiring and using `Shakapacker` module instead of `Webpacker`.

#### Config file
- Rename `config/shakapacker.yml` to `config/webpacker.yml`.
- Change `webpacker_precompile` entry to `shakapacker_precompile` if it exists in the config file.
- If you use `Shakapacker.config.webpacker_precompile?` method, replace it with `Shakapacker.config.shakapacker_precompile?`

#### Binstubs
- `bin/webpacker` and `bin/webpacker-dev-server` are renamed to `bin/shakapacker` and `bin/shakapacker-dev-server`. Since there are internal changes as well, the best way is to run `rake shakapacker:binstubs` to get the new files in place. If you haven't changed the content of these files, you can safely remove them and use the newly created files.

#### Environment variables

- All the environment variables in the format of `WEBPACKER_XYZ` should be renamed to `SHAKAPACKER_XYZ`.

#### server options

- If you use `--debug-webpacker` for your `bin/webpacker` or `bin/webpacker-dev-server`, now you should use `--debug-shakapacker`.

### Upgrade to v7

If you have successfully upgraded to version 6.6.x and have no deprecation message in your console, You should be all set to upgrade your Shakapacker to version 7. Details on this upgrade will be added with version 7 release.
