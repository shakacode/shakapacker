// Opt-in Babel 8 compatibility smoke.
//
// The normal test suite intentionally keeps repository development pins on
// Babel 7. Enable this smoke with RUN_BABEL8_SMOKE=1 after `yarn build`; it
// installs Babel 8 packages into a temp app and runs Webpack through
// babel-loader 10 with Shakapacker's built Babel preset.

const { spawnSync } = require("child_process")
const fs = require("fs")
const { createRequire } = require("module")
const os = require("os")
const path = require("path")

const repoRoot = path.resolve(__dirname, "../..")
const builtPackageDir = path.join(repoRoot, "package")
const builtPresetPath = path.join(builtPackageDir, "babel/preset.js")
const webpackPath = require.resolve("webpack")
const babel8SmokePackages = [
  "@babel/core@8.0.1",
  "@babel/plugin-transform-runtime@8.0.1",
  "@babel/preset-env@8.0.2",
  "@babel/runtime@8.0.0",
  "babel-loader@10.1.1"
]
const optedIn = process.env.RUN_BABEL8_SMOKE === "1"
const coreIsBuilt = fs.existsSync(builtPresetPath)

const toolVersion = (cmd) => {
  const r = spawnSync(cmd, ["--version"], {
    encoding: "utf8",
    cwd: os.tmpdir()
  })
  return r.status === 0 ? r.stdout.trim() : null
}

const npmVersion = toolVersion("npm")
const hasNpm = npmVersion !== null
const shouldRun = optedIn && coreIsBuilt && hasNpm

const run = (cmd, args, options) => {
  const r = spawnSync(cmd, args, {
    encoding: "utf8",
    timeout: 180000,
    ...options
  })
  if (r.status !== 0) {
    throw new Error(
      `${cmd} ${args.join(" ")} failed in ${options.cwd}\nstdout:\n${r.stdout}\nstderr:\n${r.stderr}`
    )
  }
  return r
}

const packageVersion = (appRequire, packageName) => {
  const packageJsonPath = appRequire.resolve(`${packageName}/package.json`)
  return appRequire(packageJsonPath).version
}

const installBuiltShakapackerPackage = (workRoot) => {
  const packageRoot = path.join(workRoot, "node_modules/shakapacker")
  const sourcePackageJson = JSON.parse(
    fs.readFileSync(path.join(repoRoot, "package.json"), "utf8")
  )
  fs.mkdirSync(packageRoot, { recursive: true })
  fs.writeFileSync(
    path.join(packageRoot, "package.json"),
    JSON.stringify(
      {
        name: sourcePackageJson.name,
        version: sourcePackageJson.version,
        private: true,
        main: sourcePackageJson.main,
        exports: sourcePackageJson.exports,
        files: sourcePackageJson.files
      },
      null,
      2
    )
  )

  fs.cpSync(builtPackageDir, path.join(packageRoot, "package"), {
    recursive: true
  })
}

const writeWebpackSmokeRunner = ({ workRoot, srcDir, distDir, presetPath }) => {
  const runnerPath = path.join(workRoot, "run-webpack-smoke.cjs")
  fs.writeFileSync(
    runnerPath,
    `
const { createRequire } = require("module")
const path = require("path")
const webpack = require(${JSON.stringify(webpackPath)})

const workRoot = ${JSON.stringify(workRoot)}
const srcDir = ${JSON.stringify(srcDir)}
const distDir = ${JSON.stringify(distDir)}
const presetPath = ${JSON.stringify(presetPath)}
const appRequire = createRequire(path.join(workRoot, "package.json"))

const compiler = webpack({
  mode: "development",
  context: workRoot,
  entry: path.join(srcDir, "index.js"),
  output: {
    path: distDir,
    filename: "bundle.js"
  },
  module: {
    rules: [
      {
        test: /\\.js$/,
        include: srcDir,
        use: [
          {
            loader: appRequire.resolve("babel-loader"),
            options: {
              cacheDirectory: false,
              cwd: workRoot,
              envName: "production",
              presets: [presetPath]
            }
          }
        ]
      }
    ]
  },
  optimization: {
    minimize: false
  }
})

const finish = (failure) => {
  compiler.close((closeError) => {
    const finalError = closeError || failure
    if (finalError) {
      console.error(finalError.stack || finalError.message || String(finalError))
      process.exit(1)
    }
  })
}

compiler.run((error, stats) => {
  if (error) {
    finish(error)
    return
  }

  if (stats.hasErrors()) {
    finish(
      new Error(
        stats.toString({
          all: false,
          errors: true,
          errorDetails: true,
          moduleTrace: true
        })
      )
    )
    return
  }

  finish()
})
`
  )
  return runnerPath
}

const computeSkipReason = () => {
  if (!optedIn) return "RUN_BABEL8_SMOKE=1 not set"
  if (!coreIsBuilt) return "shakapacker not built (run `yarn build`)"
  if (!hasNpm) return "npm unavailable on PATH"
  return "unknown skip reason"
}

describe("Babel 8 preset smoke (issue #1191)", () => {
  let workRoot

  beforeAll(() => {
    if (!shouldRun) return

    workRoot = fs.mkdtempSync(path.join(os.tmpdir(), "shaka-babel8-smoke-"))
    fs.writeFileSync(
      path.join(workRoot, "package.json"),
      JSON.stringify({ name: "shaka-babel8-smoke", private: true }, null, 2)
    )
    run(
      "npm",
      [
        "install",
        "--no-audit",
        "--no-fund",
        "--save-dev",
        ...babel8SmokePackages
      ],
      { cwd: workRoot }
    )
    installBuiltShakapackerPackage(workRoot)
  }, 180000)

  afterAll(() => {
    if (!workRoot) return
    fs.rmSync(workRoot, { recursive: true, force: true })
  })

  if (!shouldRun) {
    test.todo(`Babel 8 smoke skipped (${computeSkipReason()})`)
    return
  }

  test("compiles through babel-loader 10 with the Shakapacker Babel preset and Babel 8", () => {
    const srcDir = path.join(workRoot, "src")
    const distDir = path.join(workRoot, "dist")
    fs.mkdirSync(srcDir)
    const entryPath = path.join(srcDir, "index.js")
    fs.writeFileSync(entryPath, "var answer = 42;\nconsole.log(answer);\n")

    const appRequire = createRequire(path.join(workRoot, "package.json"))
    const presetPath = appRequire.resolve("shakapacker/package/babel/preset.js")
    expect(packageVersion(appRequire, "@babel/core")).toBe("8.0.1")
    expect(packageVersion(appRequire, "@babel/preset-env")).toBe("8.0.2")
    expect(packageVersion(appRequire, "@babel/plugin-transform-runtime")).toBe(
      "8.0.1"
    )
    expect(packageVersion(appRequire, "@babel/runtime")).toBe("8.0.0")
    expect(packageVersion(appRequire, "babel-loader")).toBe("10.1.1")

    const runnerPath = writeWebpackSmokeRunner({
      workRoot,
      srcDir,
      distDir,
      presetPath
    })

    run(process.execPath, [runnerPath], {
      cwd: workRoot,
      env: { ...process.env, BABEL_ENV: "production" }
    })

    expect(fs.readFileSync(path.join(distDir, "bundle.js"), "utf8")).toContain(
      "42"
    )
  }, 180000)
})
