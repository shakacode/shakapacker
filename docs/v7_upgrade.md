# Upgrading from Shakapacker v6 to v7

There will be several substantial and breaking changes in Shakapacker v7 that you need to manually account for when coming from Shakapacker v6.

## Usages of 'webpacker' should now be 'shakapacker'

Shakapacker v6 kept the 'webpacker' spelling. As a result, many config filenames, environment variables, rake tasks, etc., used the 'webpacker' spelling. Shakapacker 7 requires renaming to the 'shakapacker' spelling.

Shakapacker v7 provides a high degree of backward compatibility for spelling changes. It displays deprecation messages in the terminal to help the developers have a smooth experience in making the required transition to the new requirements.

Please note that Shakapacker v8 will remove any backward compatibility for spelling.

### Upgrade Steps

**Note:** At each step of changing the version, ensure that you update both gem and npm versions to the same "exact" version (like `x.y.z` and not `^x.y.z` or `>= x.y.z`).

1. Upgrade Shakapacker to the latest 6.x version and ensure no issues running your application. 
2. Upgrade Shakapacker to version 7.
3. Run `rake shakapacker:binstubs` to get the new files in place. Then delete the `bin/webpacker` and `bin/webpacker-dev-server` ones.
4. Change spelling from Webpacker to Shakapacker in the code
   - Change `webpacker_precompile` entry to `shakapacker_precompile` if it exists in the config file.
   - Rename Ruby constant `Webpacker` to `Shakapacker` doing a global search and replace in your code. You might not be using it.
     - Rename`Shakapacker.config.webpacker_precompile?` method, replace it with `Shakapacker.config.shakapacker_precompile?`
   - `--debug-webpacker` is now `--debug-shakapacker` for your shakapacker binstubs.
5. Rename files
    - Rename `config/shakapacker.yml` to `config/webpacker.yml`.
    - Rename environment variables from `WEBPACKER_XYZ` to `SHAKAPACKER_XYZ`.
6. Where you have used webpackConfig, you now need to invoke it as it is a function. Alternatively, you can rename the import to globalMutableWebpackConfig which retains the v6 behavior.
7. You may need to upgrade dependencies in package.json. You should use `yarn upgrade-interactive`. Note, some upgrades introduce issues. Some will fix issues. You may need to try a few different versions of a dependency to find one that works.


## The `webpackConfig` property is changed

The `webpackConfig` property in the `shakapacker` module has been updated to be a function instead of a global mutable webpack configuration. This function now returns an immutable webpack configuration object, which ensures that any modifications made to it will not affect any other usage of the webpack configuration. If a project still requires the old mutable object, it can be accessed by replacing `webpackConfig` with `globalMutableWebpackConfig`.

### Upgrade Steps

- Check config files in `config/webpack` directory. You may need to use something like the following code to get immutable config file:

   ```js
   const { webpackConfig: getWebpackConfig } = require('shakapacker')
   const webpackConfig = getWebpackConfig()
   ```
- Replace `webpackConfig` with `globalMutableWebpackConfig` if the project requires to get mutable object.
