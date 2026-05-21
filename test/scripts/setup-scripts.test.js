const fs = require("fs")
const os = require("os")
const path = require("path")
const { spawnSync } = require("child_process")

const rootDir = path.resolve(__dirname, "../..")
const conductorSetupPath = path.join(rootDir, "conductor-setup.sh")
const nodeVersionCheckPath = path.join(rootDir, "bin/lib/node-version-check.sh")
const binSetupPath = path.join(rootDir, "bin/setup")

const hasZsh =
  spawnSync("zsh", ["--version"], { encoding: "utf8" }).status === 0
if (!hasZsh) {
  console.warn(
    "[setup-scripts.test.js] zsh not found — conductor-setup.sh tests will be skipped. Install zsh to run them."
  )
}
const zshDescribe = hasZsh ? describe : describe.skip

describe("setup scripts", () => {
  let tempDir
  let fakeBin

  function copyScript(relativePath) {
    const source = path.join(rootDir, relativePath)
    const destination = path.join(tempDir, relativePath)
    fs.mkdirSync(path.dirname(destination), { recursive: true })
    fs.copyFileSync(source, destination)
    fs.chmodSync(destination, 0o755)
  }

  function writeExecutable(name, content) {
    const filePath = path.join(fakeBin, name)
    fs.writeFileSync(filePath, content, "utf8")
    fs.chmodSync(filePath, 0o755)
  }

  function installFakeTools({ failMv = false } = {}) {
    writeExecutable(
      "mise",
      '#!/usr/bin/env bash\ncase "$1" in\n  trust|install) exit 0 ;;\n  *) exit 0 ;;\nesac\n'
    )
    writeExecutable(
      "ruby",
      '#!/usr/bin/env bash\necho "ruby 3.3.4 (2024-07-09 revision be1089c8ec)"\n'
    )
    writeExecutable(
      "node",
      `#!/usr/bin/env bash\necho "\${FAKE_NODE_VERSION:-v22.20.0}"\n`
    )
    writeExecutable("bundle", "#!/usr/bin/env bash\nexit 0\n")
    writeExecutable("yarn", "#!/usr/bin/env bash\nexit 0\n")
    writeExecutable("npx", "#!/usr/bin/env bash\nexit 0\n")
    if (failMv) {
      writeExecutable(
        "mv",
        '#!/usr/bin/env bash\nif [[ "$1" == ".tool-versions.tmp" ]]; then\n  exit 1\nfi\n/bin/mv "$@"\n'
      )
    }
  }

  function runConductorSetup(extraEnv = {}) {
    return spawnSync("zsh", ["-f", "conductor-setup.sh"], {
      cwd: tempDir,
      env: {
        ...process.env,
        ...extraEnv,
        PATH: `${fakeBin}:${process.env.PATH}`
      },
      encoding: "utf8"
    })
  }

  function runBinSetup(extraEnv = {}) {
    return spawnSync("bash", ["bin/setup"], {
      cwd: tempDir,
      env: {
        ...process.env,
        ...extraEnv,
        BASH_ENV: "",
        PATH: `${fakeBin}:${process.env.PATH}`
      },
      encoding: "utf8"
    })
  }

  beforeEach(() => {
    tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "setup-scripts-test-"))
    fakeBin = path.join(tempDir, "fake-bin")
    fs.mkdirSync(fakeBin)
    fs.mkdirSync(path.join(tempDir, ".husky"))
    copyScript("conductor-setup.sh")
    copyScript("bin/setup")
    if (fs.existsSync(nodeVersionCheckPath)) {
      copyScript("bin/lib/node-version-check.sh")
    }
  })

  afterEach(() => {
    fs.rmSync(tempDir, { recursive: true, force: true })
  })

  zshDescribe("conductor-setup.sh", () => {
    it("points mise users at .mise.toml when it controls an unsupported Node version", () => {
      installFakeTools()
      fs.writeFileSync(
        path.join(tempDir, ".mise.toml"),
        '[tools]\nnode = "21.0.0"\n'
      )
      fs.writeFileSync(path.join(tempDir, ".tool-versions"), "nodejs 22.20.0\n")

      const result = runConductorSetup({ FAKE_NODE_VERSION: "v21.0.0" })

      expect(result.status).toBe(1)
      expect(result.stderr).toContain(".mise.toml")
      expect(result.stderr).not.toContain("after fixing .tool-versions")
    })

    it("prints new .tool-versions entries when adding missing tools", () => {
      installFakeTools()
      fs.writeFileSync(path.join(tempDir, ".ruby-version"), "3.3.4\n")
      fs.writeFileSync(path.join(tempDir, ".node-version"), "22.20.0\n")
      fs.writeFileSync(path.join(tempDir, ".tool-versions"), "ruby 3.3.4\n")

      const result = runConductorSetup()

      expect(result.status).toBe(0)
      expect(result.stdout).toContain("nodejs: (new) 22.20.0")
      expect(
        fs.readFileSync(path.join(tempDir, ".tool-versions"), "utf8")
      ).toBe("ruby 3.3.4\nnodejs 22.20.0\n")
    })

    it("removes .tool-versions.tmp if replacing an existing tool line fails", () => {
      installFakeTools({ failMv: true })
      fs.writeFileSync(path.join(tempDir, ".ruby-version"), "3.3.4\n")
      fs.writeFileSync(path.join(tempDir, ".node-version"), "22.20.0\n")
      fs.writeFileSync(
        path.join(tempDir, ".tool-versions"),
        "ruby 3.2.2\nnodejs 22.20.0\n"
      )

      const result = runConductorSetup()

      expect(result.status).not.toBe(0)
      expect(fs.existsSync(path.join(tempDir, ".tool-versions.tmp"))).toBe(
        false
      )
    })

    it("updates a stale nodejs entry in .tool-versions to match .node-version", () => {
      installFakeTools()
      fs.writeFileSync(path.join(tempDir, ".ruby-version"), "3.3.4\n")
      fs.writeFileSync(path.join(tempDir, ".node-version"), "22.20.0\n")
      fs.writeFileSync(
        path.join(tempDir, ".tool-versions"),
        "ruby 3.3.4\nnodejs 22.2.0\n"
      )

      const result = runConductorSetup()

      expect(result.status).toBe(0)
      expect(result.stdout).toContain("nodejs: 22.2.0 → 22.20.0")
      expect(
        fs.readFileSync(path.join(tempDir, ".tool-versions"), "utf8")
      ).toBe("ruby 3.3.4\nnodejs 22.20.0\n")
    })

    it("accepts a v-prefixed .node-version and writes the version without the prefix to .tool-versions", () => {
      installFakeTools()
      fs.writeFileSync(path.join(tempDir, ".ruby-version"), "3.3.4\n")
      fs.writeFileSync(path.join(tempDir, ".node-version"), "v22.20.0\n")

      const result = runConductorSetup()

      expect(result.status).toBe(0)
      const toolVersions = fs.readFileSync(
        path.join(tempDir, ".tool-versions"),
        "utf8"
      )
      expect(toolVersions).toContain("nodejs 22.20.0")
      expect(toolVersions).not.toContain("nodejs v22.20.0")
    })

    it("does not rewrite .tool-versions when versions already match", () => {
      installFakeTools()
      fs.writeFileSync(path.join(tempDir, ".ruby-version"), "3.3.4\n")
      fs.writeFileSync(path.join(tempDir, ".node-version"), "22.20.0\n")
      const toolVersionsPath = path.join(tempDir, ".tool-versions")
      // Compare contents instead of mtime — mtime granularity varies by filesystem
      // (1s on HFS+ and some Docker volumes) and would let a same-second rewrite slip through.
      const contentsBefore = "ruby 3.3.4\nnodejs 22.20.0\n"
      fs.writeFileSync(toolVersionsPath, contentsBefore)

      const result = runConductorSetup()

      expect(result.status).toBe(0)
      expect(result.stdout).not.toContain("Updating .tool-versions")
      expect(result.stdout).toContain(".tool-versions already in sync")
      expect(fs.readFileSync(toolVersionsPath, "utf8")).toBe(contentsBefore)
    })

    it("preserves a supported nodejs pin in .tool-versions when .node-version is absent", () => {
      installFakeTools()
      fs.writeFileSync(path.join(tempDir, ".ruby-version"), "3.3.4\n")
      // No .node-version — the supported pin in .tool-versions should be authoritative
      // instead of being silently downgraded to DEFAULT_NODE_VERSION.
      const contentsBefore = "ruby 3.3.4\nnodejs 23.5.0\n"
      fs.writeFileSync(path.join(tempDir, ".tool-versions"), contentsBefore)

      const result = runConductorSetup({ FAKE_NODE_VERSION: "v23.5.0" })

      expect(result.status).toBe(0)
      expect(
        fs.readFileSync(path.join(tempDir, ".tool-versions"), "utf8")
      ).toBe(contentsBefore)
    })

    it("rejects a malformed pre-release Node version like 22.12.0-rc1", () => {
      installFakeTools()
      fs.writeFileSync(path.join(tempDir, ".ruby-version"), "3.3.4\n")
      fs.writeFileSync(path.join(tempDir, ".node-version"), "22.12.0-rc1\n")

      const result = runConductorSetup({ FAKE_NODE_VERSION: "v22.12.0-rc1" })

      expect(result.status).not.toBe(0)
      expect(result.stderr).toContain("unsupported")
      expect(result.stderr).toContain(".node-version")
    })

    it("appends a new entry on its own line when .tool-versions lacks a trailing newline", () => {
      installFakeTools()
      fs.writeFileSync(path.join(tempDir, ".ruby-version"), "3.3.4\n")
      // No .node-version; a supported nodejs pin in .tool-versions stays authoritative.
      // Seed .tool-versions WITHOUT a trailing newline so the append path is exercised.
      fs.writeFileSync(path.join(tempDir, ".tool-versions"), "nodejs 22.20.0")

      const result = runConductorSetup()

      expect(result.status).toBe(0)
      expect(
        fs.readFileSync(path.join(tempDir, ".tool-versions"), "utf8")
      ).toBe("nodejs 22.20.0\nruby 3.3.4\n")
    })
  })

  describe("bin/setup", () => {
    it("rejects an unsupported Node version", () => {
      installFakeTools()
      const result = runBinSetup({ FAKE_NODE_VERSION: "v21.0.0" })

      expect(result.status).not.toBe(0)
      expect(result.stderr).toContain("unsupported")
    })

    it("accepts a v-prefixed supported Node version", () => {
      installFakeTools()
      const result = runBinSetup({ FAKE_NODE_VERSION: "v22.20.0" })

      expect(result.status).toBe(0)
    })

    it("surfaces the raw output when node -v cannot be parsed", () => {
      installFakeTools()
      writeExecutable("node", '#!/usr/bin/env bash\necho "garbage output"\n')

      const result = runBinSetup()

      expect(result.status).not.toBe(0)
      expect(result.stderr).toContain("Could not parse Node.js version")
      expect(result.stderr).toContain("garbage output")
    })
  })

  it("keeps the Node engine check in a shared sourced script", () => {
    const conductorSetup = fs.readFileSync(conductorSetupPath, "utf8")
    const binSetup = fs.readFileSync(binSetupPath, "utf8")

    expect(fs.existsSync(nodeVersionCheckPath)).toBe(true)
    expect(conductorSetup).toContain("bin/lib/node-version-check.sh")
    expect(binSetup).toContain("bin/lib/node-version-check.sh")
    expect(conductorSetup).not.toMatch(/^node_version_supported\(\)/m)
    expect(binSetup).not.toMatch(/^node_version_supported\(\)/m)
  })
})
