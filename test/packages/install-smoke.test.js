// Install smoke test for the shakapacker-webpack supplemental package.
//
// Verifies the resolution matrix documented in
// docs/migration/v10.1-supplemental-packages.md:
//
//                          shakapacker resolvable from app code?
//   npm 7+, wrapper-only:  YES (npm hoists the wrapper's transitive deps)
//   npm 7+, explicit-deps: YES (shakapacker declared by the app)
//   pnpm,   wrapper-only:  NO  (strict isolation; shakapacker is transitive,
//                                lives inside .pnpm/, not at app root)
//   pnpm,   explicit-deps: YES (shakapacker declared by the app)
//
// This test is opt-in because it shells out to package managers, hits the
// npm registry for bundler peers, and takes 60–120s end-to-end. Enable
// with RUN_INSTALL_SMOKE=1 (and a dedicated CI job). Auto-skips if the
// core TypeScript hasn't been built, or if the required PMs aren't on
// PATH. The npm case also auto-skips on npm < 8.3 because the
// wrapperOnlyManifest uses the `overrides` field (npm 8.3+ feature) to
// point shakapacker at the local tarball; older npm silently ignores it
// and tries to resolve `shakapacker: ~10.1.0-rc.1` from the registry.
//
// Failure here ≠ a bug in your edit; usually it means the documented
// migration matrix changed. Update the docs and these assertions together.

const { spawnSync } = require("child_process")
const fs = require("fs")
const os = require("os")
const path = require("path")

const repoRoot = path.resolve(__dirname, "../..")
const webpackSupplementalDir = path.join(
  repoRoot,
  "packages/shakapacker-webpack"
)

const optedIn = process.env.RUN_INSTALL_SMOKE === "1"
const coreIsBuilt = fs.existsSync(path.join(repoRoot, "package/index.js"))

// Probe from os.tmpdir() rather than the jest CWD so corepack's
// project-spec interception doesn't false-negative pnpm in repos that
// pin a different packageManager. The smoke test always runs commands
// from a fresh temp dir anyway.
const toolVersion = (cmd) => {
  const r = spawnSync(cmd, ["--version"], {
    encoding: "utf8",
    cwd: os.tmpdir()
  })
  return r.status === 0 ? r.stdout.trim() : null
}

const npmVersion = toolVersion("npm")
const pnpmVersion = toolVersion("pnpm")
const hasNpm = npmVersion !== null
const hasPnpm = pnpmVersion !== null

// The `overrides` manifest field is npm 8.3+. Older npm silently ignores
// it, which would cause wrapperOnlyManifest to resolve shakapacker from
// the registry instead of the local tarball.
const npmSupportsOverrides = (() => {
  if (!npmVersion) return false
  const [major, minor] = npmVersion.split(".").map(Number)
  return major > 8 || (major === 8 && minor >= 3)
})()
const npmUsable = hasNpm && npmSupportsOverrides
const shouldRun = optedIn && coreIsBuilt && (npmUsable || hasPnpm)

const packTarball = (cwd) => {
  const r = spawnSync("npm", ["pack", "--json"], { cwd, encoding: "utf8" })
  if (r.status !== 0) {
    throw new Error(`npm pack failed in ${cwd}\n${r.stderr}`)
  }
  const meta = JSON.parse(r.stdout)
  return path.join(cwd, meta[0].filename)
}

const writeJson = (file, value) =>
  fs.writeFileSync(file, JSON.stringify(value, null, 2))

const writeText = (file, value) => fs.writeFileSync(file, value)

const runInstall = (dir, cmd) => {
  // Pin behavior so the test doesn't depend on the caller's npmrc:
  // - isolated node-linker (the failure mode being tested only shows up
  //   under pnpm's strict layout; the global ~/.npmrc could override).
  // - auto-install-peers=true so required peers land at app root for
  //   modern installs (npm 7+ already does this, pnpm 8+ defaults to it).
  writeText(
    path.join(dir, ".npmrc"),
    "node-linker=isolated\nauto-install-peers=true\n"
  )
  // --no-audit/--no-fund are npm-only flags; pnpm rejects them.
  const args =
    cmd === "npm" ? ["install", "--no-audit", "--no-fund"] : ["install"]
  const r = spawnSync(cmd, args, { cwd: dir, encoding: "utf8" })
  if (r.status !== 0) {
    throw new Error(
      `${cmd} install failed in ${dir}\nstdout:\n${r.stdout}\nstderr:\n${r.stderr}`
    )
  }
}

// Use the app's CWD, not Jest's, so the resolution honors the freshly
// installed node_modules and pnpm's strict layout. require.resolve from
// inside the Jest process would always see the workspace's node_modules.
const resolvesFromAppRoot = (dir, mod) => {
  const r = spawnSync(
    "node",
    [
      "-e",
      `try { console.log(require.resolve(${JSON.stringify(mod)})); } ` +
        `catch (e) { process.stderr.write(e.message); process.exit(1); }`
    ],
    { cwd: dir, encoding: "utf8" }
  )
  return r.status === 0 && r.stdout.trim().length > 0
}

let workRoot
let coreTarball
let webpackTarball

const wrapperOnlyManifest = () => ({
  name: "smoke-wrapper-only",
  private: true,
  dependencies: {
    "shakapacker-webpack": `file:${webpackTarball}`
  },
  // Override shakapacker to our locally-packed tarball so the supplemental's
  // `dependencies.shakapacker: "~10.1.0-rc.1"` resolves to the source under
  // test rather than whatever the registry happens to have published.
  overrides: { shakapacker: `file:${coreTarball}` },
  pnpm: { overrides: { shakapacker: `file:${coreTarball}` } },
  resolutions: { shakapacker: `file:${coreTarball}` }
})

const explicitDepsManifest = () => ({
  name: "smoke-explicit",
  private: true,
  dependencies: {
    "shakapacker-webpack": `file:${webpackTarball}`,
    shakapacker: `file:${coreTarball}`,
    webpack: "^5.101.0",
    "webpack-cli": "^7.0.0",
    "webpack-assets-manifest": "^6.0.0"
  }
})

const makeApp = (subdir, manifest) => {
  const dir = path.join(workRoot, subdir)
  fs.mkdirSync(dir, { recursive: true })
  writeJson(path.join(dir, "package.json"), manifest)
  return dir
}

const computeSkipReason = () => {
  if (!optedIn) return "RUN_INSTALL_SMOKE=1 not set"
  if (!coreIsBuilt) return "shakapacker not built (run `yarn build`)"
  if (!npmUsable && !hasPnpm) {
    if (hasNpm && !npmSupportsOverrides) {
      return `npm ${npmVersion} lacks overrides support (need 8.3+), and pnpm unavailable`
    }
    return "npm and pnpm both unavailable on PATH"
  }
  return "unknown skip reason"
}

describe("shakapacker-webpack install smoke (issue #1131)", () => {
  beforeAll(() => {
    if (!shouldRun) return
    workRoot = fs.mkdtempSync(path.join(os.tmpdir(), "shaka-smoke-"))
    coreTarball = packTarball(repoRoot)
    webpackTarball = packTarball(webpackSupplementalDir)
  }, 120000)

  afterAll(() => {
    if (!shouldRun) return
    // Best-effort cleanup; leave tarballs on failure so a developer can
    // inspect what was actually installed.
    try {
      fs.rmSync(workRoot, { recursive: true, force: true })
    } catch {
      /* ignore */
    }
    try {
      fs.rmSync(coreTarball, { force: true })
    } catch {
      /* ignore */
    }
    try {
      fs.rmSync(webpackTarball, { force: true })
    } catch {
      /* ignore */
    }
  })

  // Visible placeholder for the common no-op case (env var unset) so a
  // normal `yarn jest` run shows a single reason instead of an empty
  // describe block. Test.todo registers without a body, so the hooks
  // above never execute when no real tests are queued.
  if (!shouldRun) {
    test.todo(`install smoke skipped (${computeSkipReason()})`)
    return
  }

  describe("npm", () => {
    if (!hasNpm) {
      test.todo("npm not on PATH")
      return
    }
    if (!npmSupportsOverrides) {
      test.todo(
        `npm ${npmVersion} lacks overrides support (wrapperOnlyManifest needs npm 8.3+)`
      )
      return
    }
    test("npm wrapper-only: shakapacker resolves from app root (npm hoisting)", () => {
      const dir = makeApp("npm-wrapper-only", wrapperOnlyManifest())
      runInstall(dir, "npm")
      expect(resolvesFromAppRoot(dir, "shakapacker")).toBe(true)
    }, 180000)

    test("npm explicit-deps: shakapacker resolves from app root", () => {
      const dir = makeApp("npm-explicit", explicitDepsManifest())
      runInstall(dir, "npm")
      expect(resolvesFromAppRoot(dir, "shakapacker")).toBe(true)
    }, 180000)
  })

  describe("pnpm", () => {
    if (!hasPnpm) {
      test.todo("pnpm not on PATH")
      return
    }
    test("pnpm wrapper-only: shakapacker does NOT resolve from app root (strict isolation)", () => {
      const dir = makeApp("pnpm-wrapper-only", wrapperOnlyManifest())
      runInstall(dir, "pnpm")
      // This is the exact failure mode documented in the migration guide:
      // pnpm isolates shakapacker under .pnpm/, so app-level
      // `require("shakapacker")` (e.g. from webpack.config.js) cannot find it.
      expect(resolvesFromAppRoot(dir, "shakapacker")).toBe(false)
    }, 180000)

    test("pnpm explicit-deps: shakapacker resolves from app root", () => {
      const dir = makeApp("pnpm-explicit", explicitDepsManifest())
      runInstall(dir, "pnpm")
      expect(resolvesFromAppRoot(dir, "shakapacker")).toBe(true)
    }, 180000)
  })
})
