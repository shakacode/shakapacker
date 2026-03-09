const os = require("os")
const { PathNormalizer } = require("../../package/configDiffer/pathNormalizer")

describe("PathNormalizer", () => {
  describe("normalize", () => {
    test("normalizes absolute paths to relative", () => {
      const basePath = "/app/project"
      const normalizer = new PathNormalizer(basePath)

      const config = {
        output: {
          path: "/app/project/public/packs"
        }
      }

      const result = normalizer.normalize(config)

      expect(result.normalized.output.path).toBe("./public/packs")
    })

    test("preserves non-path strings", () => {
      const normalizer = new PathNormalizer("/app")

      const config = {
        mode: "production",
        name: "client"
      }

      const result = normalizer.normalize(config)

      expect(result.normalized.mode).toBe("production")
      expect(result.normalized.name).toBe("client")
    })

    test("handles nested objects", () => {
      const basePath = "/app"
      const normalizer = new PathNormalizer(basePath)

      const config = {
        output: {
          path: "/app/public",
          nested: {
            anotherPath: "/app/build"
          }
        }
      }

      const result = normalizer.normalize(config)

      expect(result.normalized.output.path).toBe("./public")
      expect(result.normalized.output.nested.anotherPath).toBe("./build")
    })

    test("handles arrays", () => {
      const basePath = "/app"
      const normalizer = new PathNormalizer(basePath)

      const config = {
        entry: ["/app/src/index.js", "/app/src/main.js"]
      }

      const result = normalizer.normalize(config)

      expect(result.normalized.entry[0]).toBe("./src/index.js")
      expect(result.normalized.entry[1]).toBe("./src/main.js")
    })

    test("preserves paths outside base path", () => {
      const normalizer = new PathNormalizer("/app/project")

      const config = {
        path: "/other/location/file.js"
      }

      const result = normalizer.normalize(config)

      expect(result.normalized.path).toBe("/other/location/file.js")
    })

    test("handles relative paths", () => {
      const normalizer = new PathNormalizer("/app")

      const config = {
        path: "./src/index.js"
      }

      const result = normalizer.normalize(config)

      expect(result.normalized.path).toContain("./")
    })

    test("normalizes exact base path to ./", () => {
      const normalizer = new PathNormalizer("/app/project")

      const config = {
        path: "/app/project"
      }

      const result = normalizer.normalize(config)

      expect(result.normalized.path).toBe("./")
    })

    test("expands home paths before normalization", () => {
      const homePath = os.homedir()
      const normalizer = new PathNormalizer(homePath)

      const config = {
        path: "~/src/index.js"
      }

      const result = normalizer.normalize(config)

      expect(result.normalized.path).toBe("./src/index.js")
    })

    test("preserves Windows absolute paths on POSIX base paths", () => {
      const normalizer = new PathNormalizer("/app/project")

      const config = {
        path: "C:\\\\app\\\\project\\\\src\\\\index.js"
      }

      const result = normalizer.normalize(config)

      expect(result.normalized.path).toBe(
        "C:\\\\app\\\\project\\\\src\\\\index.js"
      )
    })
  })

  describe("detectBasePath", () => {
    test("detects common base path from multiple paths", () => {
      const config = {
        output: {
          path: "/app/project/public/packs"
        },
        entry: "/app/project/src/index.js",
        context: "/app/project"
      }

      const basePath = PathNormalizer.detectBasePath(config)

      expect(basePath).toBeDefined()
      expect(basePath).toContain("app")
    })

    test("returns undefined when no paths found", () => {
      const config = {
        mode: "production",
        devtool: false
      }

      const basePath = PathNormalizer.detectBasePath(config)

      expect(basePath).toBeUndefined()
    })

    test("handles config with single path", () => {
      const config = {
        context: "/app/project/src"
      }

      const basePath = PathNormalizer.detectBasePath(config)

      expect(basePath).toBeDefined()
    })
  })
})
