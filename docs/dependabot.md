# Keeping Shakapacker Updated with Dependabot

Because Shakapacker ships as both a Ruby gem and an npm package, both components
must stay in lockstep (see [Upgrading Shakapacker](./common-upgrades.md#upgrading-shakapacker)).
[Dependabot](https://docs.github.com/en/code-security/dependabot) can automate
these updates, but by default it opens a separate pull request for each
ecosystem — which can land the gem and the npm package in different versions.

Dependabot's [multi-ecosystem groups](https://docs.github.com/en/code-security/reference/supply-chain-security/dependabot-options-reference#multi-ecosystem-groups-)
let you update the bundler and npm sides in a single PR.

> **Note:** Multi-ecosystem groups are a relatively recent Dependabot feature
> and may not be available on older versions of GitHub Enterprise Server.

## Example `.github/dependabot.yml`

```yml
version: 2

multi-ecosystem-groups:
  shakapacker:
    schedule:
      interval: weekly

updates:
  - package-ecosystem: bundler
    directory: "/"
    patterns: ["shakapacker"]
    multi-ecosystem-group: shakapacker

  - package-ecosystem: npm
    directory: "/"
    patterns: ["shakapacker"]
    multi-ecosystem-group: shakapacker

  # To keep the rest of your bundler/npm dependencies updated, add separate
  # `updates` entries without `multi-ecosystem-group` so they get their own
  # PRs independent of the Shakapacker group. For example:
  #
  # - package-ecosystem: bundler
  #   directory: "/"
  #   schedule:
  #     interval: weekly
  #
  # - package-ecosystem: npm
  #   directory: "/"
  #   schedule:
  #     interval: weekly
```

Note that the bundler and npm `updates` entries bound to the multi-ecosystem
group above don't declare their own `schedule:` — they inherit the cadence
from the `multi-ecosystem-groups` definition. A per-entry `schedule:` is only
required on `updates` entries that are not bound to a multi-ecosystem group
(like the commented-out skeleton above).

With this configuration, Dependabot will open a single pull request that bumps
both the `shakapacker` gem and the `shakapacker` npm package together whenever
it detects a new release during its weekly schedule run.

See [this example `dependabot.yml`](https://gist.github.com/sunny/86adfc54c9e5c54b0bc745b46a0827a8#file-dependabot-yml)
for a fuller configuration that also groups other bundler/npm updates and
applies cooldowns. Thanks to [@sunny](https://github.com/sunny) for sharing this
pattern in [discussion #1093](https://github.com/shakacode/shakapacker/discussions/1093).
