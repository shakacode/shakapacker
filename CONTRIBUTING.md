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

### 4. Run the Ruby test suite

```
bundle exec rake test
```

#### 4.1 Run a single ruby test file

```
bundle exec rake test TEST=test/rake_tasks_test.rb
```

#### 4.2 Run a single ruby test

```
bundle exec ruby -I test test/rake_tasks_test.rb -n test_rake_webpacker_install
```

## Testing the generator
If you change the generator, check that install instructions work.

1. Update the gemfile so that gem "webpacker" has a line like this, pointing to your install of webpacker
   ```ruby
   gem 'webpacker', path: "~/shakacode/forks/shakapacker"
   ```
2. `bundle`
3. Run the generator confirm that you got the right changes. 

## Find existing issues
You may look at the issues list to find existing known issues to be addressed. In this, we recommend to look at closed issues, particularly with "[help wanted](https://github.com/shakacode/shakapacker/issues?q=is%3Aissue+label%3A%22help+wanted%22+is%3Aclosed+)" label.