# Contributing Guidelines

Thank you for your interest in contributing to Shakapacker! We welcome all contributions that align with our project goals and values. To ensure a smooth and productive collaboration, please follow these guidelines.

## Contents
- [Reporting Issues](#reporting-issues)
- [Submitting Pull Requests](#submitting-pull-requests)
- [Setting Up a Development Environment](#setting-up-a-development-environment)
- [Making sure your changes pass all tests](#making-sure-your-changes-pass-all-tests)
- [Testing the generator](#testing-the-generator)

## Reporting Issues
If you encounter any issues with the project, please first check the existing issues (including closed ones). If the issues is not reported before, please opening an issue on our GitHub repository. Please provide a clear and detailed description of the issue, including steps to reproduce it. Creating a demo repository to demonstrate the issue would be ideal (and in some cases necessary).

If looking to contribute to the project by fixing existing issues, we recommend looking at issues, particularly with the "[help wanted](https://github.com/shakacode/shakapacker/issues?q=is%3Aissue+label%3A%22help+wanted%22)" label.

## Submitting Pull Requests
We welcome pull requests that fix bugs, add new features, or improve existing ones. Before submitting a pull request, please make sure to:

  - Open an issue about what you want to propose before start working on.
  - Fork the repository and create a new branch for your changes.
  - Write clear and concise commit messages.
  - Follow our code style guidelines.
  - Write tests for your changes and [make sure all tests pass](#making-sure-your-changes-pass-all-tests).
  - Update the documentation as needed.
  - Update CHANGELOG.md if the changes affect public behavior of the project.

---
## Setting Up a Development Environment

1. Install [Yarn](https://classic.yarnpkg.com/)
2. To test your changes on a Rails test project do the following steps:
   - For Ruby gem, update `Gemfile` and point the `shakapacker` to the locally developing Shakapacker project:
      ```ruby
      gem 'shakapacker', path: "relative_or_absolute_path_to_local_shakapacker"
      ```
   - For npm package, use `yalc` with following steps:
      ```bash
      # In Shakapacker root directory
      yalc publish
      # In Rails app for testing
      yalc link shakapacker

      # After every change in shakapacker, run the following in Shakapacker directory
      yalc push # or yalc publish --push
      ```
3. Run the following commands to set up the development environment.
   ```
   bundle install
   yarn install
   ```

## Making sure your changes pass all tests

There are several specs, covering different aspects of Shakapacker gem. You may run them locally or rely on GitHub CI actions configured to test the gem functionality if different Ruby, Rails, and Node environment.

We request running tests locally to ensure the new changes would not break the CI build.

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

Note: For this, you need `yalc` to be installed on your local machine

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
These specs are to check Shakapacker v7 backward compatibility with v6.x

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
