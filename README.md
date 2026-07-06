<p align="center">
  <a href="https://shakapacker.com">
    <img src="./assets/brand/lockup-light.png?raw=true" alt="Shakapacker: Rails asset bundling with modern build systems" width="760">
  </a>
</p>

# Shakapacker (v10)

Shakapacker is the official, actively maintained successor to
[rails/webpacker](https://github.com/rails/webpacker). It gives Rails apps a
manifest-backed bridge to webpack 5 or Rspack, with view helpers, installer
tasks, binstubs, and configuration conventions that still allow direct bundler
customization.

_Shakapacker 10 supports [Rspack](https://rspack.rs/) — up to 17x faster than
webpack per
[upstream benchmarks](https://shakapacker.com/docs/transpiler-performance/#published-benchmarks)._

The canonical markdown source stays in this repository's [`docs/`](./docs/)
directory and is published to the docs site.

<p align="center">
  <a href="https://shakapacker.com/docs/">
    <img src="https://img.shields.io/badge/%F0%9F%93%96%20Read%20the%20Docs-shakapacker.com-cc0000?style=for-the-badge" alt="Read the Shakapacker documentation at shakapacker.com">
  </a>
</p>

[![Ruby based checks](https://github.com/shakacode/shakapacker/actions/workflows/ruby.yml/badge.svg)](https://github.com/shakacode/shakapacker/actions/workflows/ruby.yml)
[![Node based checks](https://github.com/shakacode/shakapacker/actions/workflows/node.yml/badge.svg)](https://github.com/shakacode/shakapacker/actions/workflows/node.yml)
[![Generator specs](https://github.com/shakacode/shakapacker/actions/workflows/generator.yml/badge.svg)](https://github.com/shakacode/shakapacker/actions/workflows/generator.yml)
[![Test Both Bundlers](https://github.com/shakacode/shakapacker/actions/workflows/test-bundlers.yml/badge.svg)](https://github.com/shakacode/shakapacker/actions/workflows/test-bundlers.yml)

[![node.js](https://img.shields.io/badge/node-%5E20.19.0%20%7C%7C%20%3E%3D22.12.0-brightgreen.svg)](https://www.npmjs.com/package/shakapacker)
[![shakapacker gem version](https://img.shields.io/gem/v/shakapacker.svg?label=shakapacker%20gem)](https://rubygems.org/gems/shakapacker)
[![shakapacker npm package version](https://img.shields.io/npm/v/shakapacker.svg?label=shakapacker%20package)](https://www.npmjs.com/package/shakapacker)
[![shakapacker-webpack npm package version](https://img.shields.io/npm/v/shakapacker-webpack.svg?label=shakapacker-webpack%20package)](https://www.npmjs.com/package/shakapacker-webpack)
[![shakapacker-rspack npm package version](https://img.shields.io/npm/v/shakapacker-rspack.svg?label=shakapacker-rspack%20package)](https://www.npmjs.com/package/shakapacker-rspack)

## Documentation

Full documentation lives at **[shakapacker.com/docs](https://shakapacker.com/docs/)**. Start here:

| Need                                     | Link                                                                                |
| ---------------------------------------- | ----------------------------------------------------------------------------------- |
| Decide if Shakapacker + Rspack is right  | [Why Shakapacker with Rspack](https://shakapacker.com/docs/why-shakapacker-rspack/) |
| Install Shakapacker                      | [Installation](https://shakapacker.com/docs/installation/)                          |
| Configure `config/shakapacker.yml`       | [Configuration](https://shakapacker.com/docs/configuration/)                        |
| Use the JavaScript/Node API              | [Node Package API](https://shakapacker.com/docs/node_package_api/)                  |
| Render assets with view helpers          | [API Reference](https://shakapacker.com/docs/api-reference/)                        |
| Add React, TypeScript, or CSS            | [React & integrations](https://shakapacker.com/docs/react/)                         |
| Move from webpack to Rspack              | [Rspack Migration](https://shakapacker.com/docs/rspack_migration_guide/)            |
| Compare generated webpack/Rspack configs | [Config Diff](https://shakapacker.com/docs/config-diff/)                            |
| Deploy compiled assets                   | [Deployment](https://shakapacker.com/docs/deployment/)                              |
| Upgrade an existing app                  | [Common Upgrades](https://shakapacker.com/docs/common-upgrades/)                    |
| Troubleshoot builds                      | [Troubleshooting](https://shakapacker.com/docs/troubleshooting/)                    |
| Review releases                          | [Changelog](./CHANGELOG.md)                                                         |

## Why Shakapacker

- Rails-native manifest integration and view helpers for bundled assets.
- Support for webpack 5 and first-class Rspack builds.
- JavaScript and TypeScript transpilation through SWC, Babel, or esbuild.
- Development binstubs for watch mode and the webpack dev server.
- Code splitting, HMR, CDN asset hosts, Subresource Integrity, and HTTP 103
  Early Hints support.
- Compatibility with npm, Yarn, pnpm, and Bun.
- Optional `shakapacker-webpack` and `shakapacker-rspack` packages in 10.1+
  that consolidate the managed bundler stack into one dependency.

### Optional support

Optional integrations require extra packages only when you use them: React,
TypeScript, stylesheets with Sass, Less, Stylus, CSS, PostCSS, and CoffeeScript.

For why you might choose this stack over importmaps, jsbundling-rails, or
vite-rails, see
[Why Shakapacker with Rspack](https://shakapacker.com/docs/why-shakapacker-rspack/).
See also a comparison of
[Shakapacker with jsbundling-rails](https://github.com/rails/jsbundling-rails/blob/main/docs/comparison_with_webpacker.md).
For an in-depth discussion of choosing between `shakapacker` and
`jsbundling-rails`, see the discussion
[Webpacker alternatives - which path should we go to? #8783](https://github.com/decidim/decidim/discussions/8783)
and the resulting PR
[Switch away from Webpacker to Shakapacker #10389](https://github.com/decidim/decidim/pull/10389).

## Installation

For an existing Rails app:

```bash
bundle add shakapacker --strict
bundle exec rake shakapacker:install
```

For a new Rails 6+ app:

```bash
rails new myapp --skip-javascript
cd myapp
bundle add shakapacker --strict
bundle exec rake shakapacker:install
```

See the [installation guide](https://shakapacker.com/docs/installation/) for
requirements, package-manager selection, non-interactive installer modes, and
verification steps.

## Upgrading

Shakapacker ships as both a Ruby gem and an npm package; keep them on matching
versions. Use the [common upgrade guides](https://shakapacker.com/docs/common-upgrades/)
for package-manager changes, Babel-to-SWC migration, webpack-to-Rspack migration,
and release-to-release upgrade paths.

Older major-version docs:

- [v10 upgrade guide](https://github.com/shakacode/shakapacker/blob/main/docs/v10_upgrade.md)
  ([docs site](https://shakapacker.com/docs/v10_upgrade/))
- [v9 upgrade guide](https://shakapacker.com/docs/v9_upgrade/)
- [v8 upgrade guide](https://shakapacker.com/docs/v8_upgrade/)
- [v7 upgrade guide](https://shakapacker.com/docs/v7_upgrade/)
- [v6 upgrade guide](https://shakapacker.com/docs/v6_upgrade/)
- [v6 stable branch](https://github.com/shakacode/shakapacker/tree/6-stable)

## Example Apps

- [React on Rails Tutorial With SSR, HMR fast refresh, and TypeScript](https://github.com/shakacode/react_on_rails_tutorial_with_ssr_and_hmr_fast_refresh)

## ShakaCode Support

[ShakaCode](https://www.shakacode.com) focuses on helping Ruby on Rails teams use React and Webpack better. We can upgrade your project and improve your development and customer experiences, allowing you to focus on building new features or fixing bugs instead.

For an overview of working with us, see our [Client Engagement Model](https://www.shakacode.com/blog/client-engagement-model/) article and [how we bill for time](https://www.shakacode.com/blog/shortcut-jira-trello-github-toggl-time-and-task-tracking/).

We also specialize in helping development teams lower infrastructure and CI costs. Check out our project [Control Plane Flow](https://github.com/shakacode/control-plane-flow/), which can allow you to get the ease of Heroku with the power of Kubernetes and big cost savings.

If you think ShakaCode can help your project, [click here](https://meetings.hubspot.com/justingordon/30-minute-consultation) to book a call with [Justin Gordon](mailto:justin@shakacode.com), the creator of React on Rails and Shakapacker.

Here's a testimonial of how ShakaCode can help from [Florian Gößler](https://github.com/FGoessler) of [Blinkist](https://www.blinkist.com/), January 2, 2023:

> Hey Justin 👋
>
> I just wanted to let you know that we today shipped the webpacker to shakapacker upgrades and it all seems to be running smoothly! Thanks again for all your support and your teams work! 😍
>
> On top of your work, it was now also very easy for me to upgrade Tailwind and include our external node_module based web component library which we were using for our other (more modern) apps already. That work is going to be shipped later this week though as we are polishing the last bits of it. 😉
>
> Have a great 2023 and maybe we get to work together again later in the year! 🙌

Read the [full review here](https://clutch.co/profile/shakacode#reviews?sort_by=date_DESC#review-2118154).

Here's a testimonial from Jon Rajavuori of [Academia.edu](https://www.academia.edu/) about migrating frontend builds from Webpack to [rspack](https://rspack.rs/) with ShakaCode's help, shared in March 2026:

> We've been running [rspack](https://rspack.rs/) most of the week now for frontend builds! It's a performance-focused drop-in replacement for Webpack that apparently works as advertised. The impact has been between a **2-4x build speed increase** depending on the environment and conditions.
>
> The typical case of first startup with a warm cache has gone from roughly 1m with Webpack down to about **20s** — close to the amount of time other dev components take to startup.
>
> As for production **incremental** builds, they now take around 10s when only a few lines in one bundle have changed!
>
> Additional stats from follow-up conversation with Jon:
>
> - Cold-cache startup: **4m30s → 3m30s** (~22% faster; 2-4x gains apply to warm-cache and incremental builds)
> - Production incremental builds: **~10 seconds**
> - HMR rebuild time: unchanged at ~8s (bottleneck is orchestration, not compilation)

## Community and Support

- Ask questions in the
  [React + Rails Slack community](https://reactrails.slack.com/join/shared_invite/enQtNjY3NTczMjczNzYxLTlmYjdiZmY3MTVlMzU2YWE0OWM0MzNiZDI0MzdkZGFiZTFkYTFkOGVjODBmOWEyYWQ3MzA2NGE1YWJjNmVlMGE).
- Report bugs or request features in
  [GitHub Issues](https://github.com/shakacode/shakapacker/issues).
- Get direct help from [ShakaCode](https://www.shakacode.com), the team that
  maintains Shakapacker and helps Rails teams migrate to Rspack, speed up build
  pipelines, and stabilize production deploys.

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for development setup, test commands,
and pull request guidelines.

## License

Shakapacker is released under the [MIT License](https://opensource.org/licenses/MIT).

## Supporters

The following companies support our Open Source projects, and ShakaCode uses their products!

<br />
<br />

<a href="https://jb.gg/OpenSource" style="margin-right: 20px;">
  <img src="https://resources.jetbrains.com/storage/products/company/brand/logos/jetbrains.png" alt="JetBrains" height="120px">
</a>
<a href="https://scoutapp.com">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://user-images.githubusercontent.com/4244251/184881147-0d077438-3978-40da-ace9-4f650d2efe2e.png">
    <source media="(prefers-color-scheme: light)" srcset="https://user-images.githubusercontent.com/4244251/184881152-9f2d8fba-88ac-4ba6-873b-22387f8711c5.png">
    <img alt="ScoutAPM" src="https://user-images.githubusercontent.com/4244251/184881152-9f2d8fba-88ac-4ba6-873b-22387f8711c5.png" height="120px">
  </picture>
</a>
<a href="https://shakacode.controlplane.com">
  <picture>
    <img alt="Control Plane" src="https://github.com/shakacode/.github/assets/20628911/90babd87-62c4-4de3-baa4-3d78ef4bec25" height="120px">
  </picture>
</a>
<br />
<a href="https://www.browserstack.com">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://user-images.githubusercontent.com/4244251/184881122-407dcc29-df78-4b20-a9ad-f597b56f6cdb.png">
    <source media="(prefers-color-scheme: light)" srcset="https://user-images.githubusercontent.com/4244251/184881129-e1edf4b7-3ae1-4ea8-9e6d-3595cf01609e.png">
    <img alt="BrowserStack" src="https://user-images.githubusercontent.com/4244251/184881129-e1edf4b7-3ae1-4ea8-9e6d-3595cf01609e.png" height="55px">
  </picture>
</a>
<a href="https://www.honeybadger.io">
  <img src="https://user-images.githubusercontent.com/4244251/184881133-79ee9c3c-8165-4852-958e-31687b9536f4.png" alt="Honeybadger" height="55px">
</a>
<a href="https://coderabbit.ai">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://victorious-bubble-f69a016683.media.strapiapp.com/White_Typemark_7229870ac5.svg">
    <source media="(prefers-color-scheme: light)" srcset="https://victorious-bubble-f69a016683.media.strapiapp.com/Orange_Typemark_7958cfa790.svg">
    <img alt="CodeRabbit" src="https://victorious-bubble-f69a016683.media.strapiapp.com/Orange_Typemark_7958cfa790.svg" height="55px">
  </picture>
</a>
