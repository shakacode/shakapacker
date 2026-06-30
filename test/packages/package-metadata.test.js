const { readFileSync } = require("fs")
const { join, resolve } = require("path")

const repoRoot = resolve(__dirname, "../..")
const webpackManifestPath = join(
  repoRoot,
  "packages/shakapacker-webpack/package.json"
)
const rspackManifestPath = join(
  repoRoot,
  "packages/shakapacker-rspack/package.json"
)
const mainManifestPath = join(repoRoot, "package.json")
const installManifestPath = join(repoRoot, "lib/install/package.json")
const installTemplatePath = join(repoRoot, "lib/install/template.rb")

const readManifest = (filePath) => JSON.parse(readFileSync(filePath, "utf8"))

// Pulled out of test bodies to keep jest/no-conditional-in-test happy.
// Returns labeled offenders so assertion failures point at the culprit.
// `hasTilde` walks the OR-separated operands so a compound range like
// `"^1.0.0 || ~2.0.0"` is still caught.
const hasTilde = (range) =>
  range.split(/\s*\|\|\s*/).some((operand) => operand.startsWith("~"))

const collectTildeOffenders = (deps, peers) => {
  const peerOffenders = Object.entries(peers)
    .filter(([, range]) => hasTilde(range))
    .map(([name, range]) => `peer ${name}: ${range}`)
  const depOffenders = Object.entries(deps)
    .filter(([name, range]) => name !== "shakapacker" && hasTilde(range))
    .map(([name, range]) => `dep ${name}: ${range}`)
  return [...peerOffenders, ...depOffenders]
}

// Runtime singletons: multiple copies break plugin `instanceof` checks.
// CLI and manifest packages: peered so the host app controls the exact
// version; duplicate copies can cause version conflicts and unpredictable
// binary resolution. Both categories MUST be required peer dependencies.
// See issue #1131 for rationale.
const WEBPACK_SINGLETONS = ["webpack", "webpack-cli", "webpack-assets-manifest"]
const RSPACK_SINGLETONS = [
  "@rspack/core",
  "@rspack/cli",
  "@rspack/dev-server",
  "rspack-manifest-plugin"
]

describe("main shakapacker/package.json", () => {
  const manifest = readManifest(mainManifestPath)
  const peers = manifest.peerDependencies || {}

  test("declares rspack peers as v2-only", () => {
    expect(peers).toMatchObject({
      "@rspack/core": "^2.0.0",
      "@rspack/cli": "^2.0.0",
      "@rspack/dev-server": "^2.0.0",
      "@rspack/plugin-react-refresh": "^2.0.0",
      "rspack-manifest-plugin": "^5.2.2"
    })
  })
})

describe("lib/install/package.json", () => {
  const manifest = readManifest(installManifestPath)
  const rspackDeps = manifest.rspack || {}

  test("installs rspack v2 dependencies only", () => {
    expect(rspackDeps).toMatchObject({
      "@rspack/core": "^2.0.0",
      "@rspack/cli": "^2.0.0",
      "@rspack/dev-server": "^2.0.0",
      "rspack-manifest-plugin": "^5.2.2"
    })
    expect(rspackDeps).not.toHaveProperty("css-loader")
  })

  test("applies rspack css-loader floor only through common loader override", () => {
    const template = readFileSync(installTemplatePath, "utf8")
    expect(template).toContain(
      'if assets_bundler == "rspack" && common_deps.key?("css-loader")'
    )
    expect(template).toContain('peers["css-loader"] = "^7.1.4"')
  })
})

describe("shakapacker-webpack/package.json", () => {
  const manifest = readManifest(webpackManifestPath)
  const deps = manifest.dependencies || {}
  const peers = manifest.peerDependencies || {}
  const peerMeta = manifest.peerDependenciesMeta || {}

  test.each(WEBPACK_SINGLETONS)(
    "declares %s as a required peer dependency",
    (pkg) => {
      expect(peers).toHaveProperty(pkg)
      expect(deps).not.toHaveProperty(pkg)
      expect(peerMeta[pkg]?.optional).not.toBe(true)
    }
  )

  test("declares terser-webpack-plugin as a direct dependency", () => {
    // package/optimization/webpack.ts does requireOrError("terser-webpack-plugin")
    // for the default minimizer config, so it is always required for any
    // production build using shakapacker's defaults. Webpack 5 happens to
    // include it transitively, but relying on that is fragile.
    expect(deps).toHaveProperty("terser-webpack-plugin")
    expect(peers).not.toHaveProperty("terser-webpack-plugin")
  })

  test("pins shakapacker with a tilde (lockstep release)", () => {
    expect(deps.shakapacker).toMatch(/^~/)
  })

  test("does not use tilde constraints for non-shakapacker packages", () => {
    // Tilde locks to the patch range, forcing a supplemental release for
    // every upstream minor. Caret (or wider) lets users pick up compatible
    // upstream versions without a coordinated shakapacker release.
    expect(collectTildeOffenders(deps, peers)).toStrictEqual([])
  })
})

describe("shakapacker-rspack/package.json", () => {
  const manifest = readManifest(rspackManifestPath)
  const deps = manifest.dependencies || {}
  const peers = manifest.peerDependencies || {}
  const peerMeta = manifest.peerDependenciesMeta || {}

  test.each(RSPACK_SINGLETONS)(
    "declares %s as a required peer dependency",
    (pkg) => {
      expect(peers).toHaveProperty(pkg)
      expect(deps).not.toHaveProperty(pkg)
      expect(peerMeta[pkg]?.optional).not.toBe(true)
    }
  )

  test("pins shakapacker with a tilde (lockstep release)", () => {
    expect(deps.shakapacker).toMatch(/^~/)
  })

  test("does not use tilde constraints for non-shakapacker packages", () => {
    expect(collectTildeOffenders(deps, peers)).toStrictEqual([])
  })
})

describe("supplemental peer ranges align with main shakapacker", () => {
  // The supplemental packages should never be stricter than the package
  // they wrap. A user on bare `shakapacker` with a valid peer version
  // should be able to adopt the supplemental without changing that peer.
  const mainManifest = readManifest(mainManifestPath)
  const mainPeers = mainManifest.peerDependencies || {}

  const collectMismatches = (supplementalManifestPath) => {
    const manifest = readManifest(supplementalManifestPath)
    const peers = manifest.peerDependencies || {}
    return Object.entries(peers)
      .filter(
        ([name, supplementalRange]) =>
          mainPeers[name] && mainPeers[name] !== supplementalRange
      )
      .map(([name, supplementalRange]) => ({
        name,
        supplementalRange,
        mainRange: mainPeers[name]
      }))
  }

  const expectOnlyKnownMismatches = (
    mismatches,
    knownIntentionalNarrowings
  ) => {
    const mismatchNames = new Set(mismatches.map((m) => m.name))
    const staleAllowlistEntries = [...knownIntentionalNarrowings]
      .filter((name) => !mismatchNames.has(name))
      .sort()
    const unexpectedMismatches = mismatches
      .filter((m) => !knownIntentionalNarrowings.has(m.name))
      .map((m) => m.name)
      .sort()

    expect({
      staleAllowlistEntries,
      unexpectedMismatches
    }).toStrictEqual({
      staleAllowlistEntries: [],
      unexpectedMismatches: []
    })
  }

  describe("known mismatch assertions", () => {
    test("fail when an allowlist entry no longer corresponds to a mismatch", () => {
      expect(() =>
        expectOnlyKnownMismatches(
          [{ name: "webpack-cli", supplementalRange: "^7.0.0" }],
          new Set(["webpack-cli", "stale-entry"])
        )
      ).toThrow(/stale-entry/)
    })
  })

  test("webpack supplemental peers match main peer ranges where both exist", () => {
    // Most shared peers should stay aligned with core shakapacker. Listed
    // mismatches are intentional curation or bundler-specific compatibility.
    const knownIntentionalMismatches = new Set([
      "webpack-cli", // supplemental curates to v7+
      "webpack-assets-manifest" // supplemental requires v6 (v5 has ENOENT bug)
    ])
    expect(() =>
      expectOnlyKnownMismatches(
        collectMismatches(webpackManifestPath),
        knownIntentionalMismatches
      )
    ).not.toThrow()
  })

  test("rspack supplemental peers match main peer ranges where both exist", () => {
    const knownIntentionalNarrowings = new Set([
      "css-loader" // v7.1.4+ declares Rspack v2 peer compatibility
    ])
    expect(() =>
      expectOnlyKnownMismatches(
        collectMismatches(rspackManifestPath),
        knownIntentionalNarrowings
      )
    ).not.toThrow()
  })
})
