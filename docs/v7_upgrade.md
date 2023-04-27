# Upgrading from Shakapacker v6 to v7

There will be several substantial and breaking changes in Shakapacker v7 that you need to manually account for when coming from Shakapacker v6.

## Noticeable Changes

### Usages of 'webpacker' should now be 'shakapacker'

Shakapacker v6 kept the 'webpacker' spelling. As a result, many config filenames, environment variables, rake tasks, etc., used the 'webpacker' spelling. Shakapacker 7 requires renaming to the 'shakapacker' spelling.

Shakapacker v7 provides a high degree of backward compatibility for spelling changes. It displays deprecation messages in the terminal to help the developers have a smooth experience in making the required transition to the new requirements.

Please note that Shakapacker v8 will remove any backward compatibility for spelling.

## Upgrade Steps

**Note:** At each step of changing the version, ensure that you update both gem and npm versions to the same "exact" version (like `x.y.z` and not `^x.y.z` or `>= x.y.z`).

1. Upgrade Shakapacker to the latest 6.x version and ensure no issues running your application. 
2. Upgrade Shakapacker to version 7.
3. Change spelling from Webpacker to Shakapacker
    - Rename constant `Webpacker` to `Shakapacker`.
    - Rename`Shakapacker.config.webpacker_precompile?` method, replace it with `Shakapacker.config.shakapacker_precompile?`
    - Rename `config/shakapacker.yml` to `config/webpacker.yml`.
    - Change `webpacker_precompile` entry to `shakapacker_precompile` if it exists in the config file.
    - Run `rake shakapacker:binstubs` to get the new files in place and delete the old webpacker ones. Alternatively, if you have updated these files manually, rename `bin/webpacker` and `bin/webpacker-dev-server` to `bin/shakapacker` and `bin/shakapacker-dev-server`, and update the content of these files to change 'webpacker' to 'shakapacker'.
    - `--debug-webpacker` is now `--debug-shakapacker` for your shakapacker binstubs.
    - Rename environment variables from `WEBPACKER_XYZ` to `SHAKAPACKER_XYZ`.
