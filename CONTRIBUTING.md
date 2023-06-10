## Contents
- [Setting Up a Development Environment](#setting-up-a-development-environment)
- [Making sure your changes pass all tests](#making-sure-your-changes-pass-all-tests)
- [Testing the generator](#testing-the-generator)
- [Find existing issues](#find-existing-issues)

---
## Setting Up a Development Environment

1. Install [Yarn](https://yarnpkg.com/)

2. Run the following commands to set up the development environment.

```
bundle install
yarn
```

## Making sure your changes pass all tests

There are a number of automated checks which run on GitHub Actions when a pull request is created.

You can run those checks on your own locally to make sure that your changes would not break the CI build.

### 1. Check the code for JavaScript style violations

```
yarn lint
```

### 2. Check the code for Ruby style violations

```
bundle exec rubocop
```

### 3. Run the JavaScript test suite

```
yarn test
```

### 4. Run all the Ruby test suite

```
bundle exec rake test
```

#### 4.1 Run a single ruby test file

```
bundle exec rspec spec/configuration_spec.rb
```

#### 4.2 Run a single ruby test

```
bundle exec rspec -e "#source_entry_path returns correct path"
```

#### 4.3 Run only Shakapacker gem specs

```
bundle exec rake run_spec:gem
```

#### 4.4 Run only Shakapacker gem specs for backward compatibility
These specs are to check Shakapcker v7 backward compatibility with v6.x

```
bundle exec rake run_spec:gem_bc
```

#### 4.5 Run dummy app test
For this, you need `yalc` to be installed on your local machine

```
bundle exec rake run_spec:dummy
```

#### 4.6 Testing the installer
To ensure that your installer works as expected, either you can run `bundle exec rake run_spec:install`, or take the following manual testing steps:

1. Update the `Gemfile` so that gem `shakapacker` has a line like this, pointing to your developing Shakapacker:
   ```ruby
   gem 'shakapacker', path: "relative_or_absolute_path_to_the_gem"
   ```
2. Run `bundle install` to install the updated gem.
3. Run `bundle exec rails shakapacker:install` to confirm that you got the right changes.

 **Note:** Ensure that you use bundle exec otherwise the installed shakapacker gem will run and not the one you are working on.

## Find existing issues
You may look at the issues list to find existing known issues to be addressed. In this, we recommend looking at closed issues, particularly with the "[help wanted](https://github.com/shakacode/shakapacker/issues?q=is%3Aissue+label%3A%22help+wanted%22+is%3Aclosed+)" label.