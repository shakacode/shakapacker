// Tests for path validation and security utilities
const {
  isPathTraversalSafe,
  safeResolvePath,
  validatePaths,
  sanitizeEnvValue,
  validatePort
} = require("../../package/utils/pathValidation")

describe("Path Validation Security", () => {
  describe("isPathTraversalSafe", () => {
    it("detects directory traversal patterns", () => {
      const unsafePaths = [
        "../etc/passwd",
        "../../secrets",
        "/etc/passwd",
        "~/ssh/keys",
        "C:\\Windows\\System32",
        "C:/Windows/System32",   // Windows with forward slash
        "D:\\Program Files",      // Different drive letter
        "\\\\server\\share\\file", // Windows UNC path
        "\\\\192.168.1.1\\share", // UNC with IP
        "%2e%2e%2fsecrets",
        "%2E%2E%2Fsecrets",      // URL encoded uppercase
        "path\x00with\x00null"    // Null bytes
      ]

      unsafePaths.forEach(path => {
        expect(isPathTraversalSafe(path)).toBe(false)
      })
    })

    it("allows safe relative paths", () => {
      const safePaths = [
        "src/index.js",
        "./components/App.tsx",
        "node_modules/package/index.js",
        "dist/bundle.js"
      ]

      safePaths.forEach(path => {
        expect(isPathTraversalSafe(path)).toBe(true)
      })
    })
  })

  describe("safeResolvePath", () => {
    it("resolves paths within base directory", () => {
      const basePath = "/app"
      const userPath = "src/index.js"
      const result = safeResolvePath(basePath, userPath)
      
      expect(result).toContain("/app")
      expect(result).toContain("src/index.js")
    })

    it("throws on traversal attempts", () => {
      const basePath = "/app"
      const maliciousPath = "../etc/passwd"
      
      expect(() => {
        safeResolvePath(basePath, maliciousPath)
      }).toThrow("Path traversal attempt detected")
    })
  })

  describe("validatePaths", () => {
    it("filters out unsafe paths with warnings", () => {
      const consoleSpy = jest.spyOn(console, "warn").mockImplementation()
      
      const paths = [
        "src/index.js",
        "../etc/passwd",
        "components/App.tsx"
      ]
      
      const result = validatePaths(paths, "/app")
      
      expect(result).toHaveLength(2)
      expect(consoleSpy).toHaveBeenCalledWith(
        expect.stringContaining("potentially unsafe path")
      )
      
      consoleSpy.mockRestore()
    })
  })

  describe("sanitizeEnvValue", () => {
    it("removes control characters", () => {
      const dirty = "normal\x00text\x1Fwith\x7Fcontrol"
      const clean = sanitizeEnvValue(dirty)
      
      expect(clean).toBe("normaltextwithcontrol")
    })

    it("warns when sanitization occurs", () => {
      const consoleSpy = jest.spyOn(console, "warn").mockImplementation()
      
      sanitizeEnvValue("text\x00with\x00nulls")
      
      expect(consoleSpy).toHaveBeenCalledWith(
        expect.stringContaining("control characters")
      )
      
      consoleSpy.mockRestore()
    })

    it("returns undefined for undefined input", () => {
      expect(sanitizeEnvValue(undefined)).toBeUndefined()
    })
  })

  describe("validatePort", () => {
    it("accepts valid port numbers", () => {
      expect(validatePort(3000)).toBe(true)
      expect(validatePort(80)).toBe(true)
      expect(validatePort(65535)).toBe(true)
    })

    it("accepts valid port strings", () => {
      expect(validatePort("3000")).toBe(true)
      expect(validatePort("auto")).toBe(true)
    })

    it("rejects invalid ports", () => {
      expect(validatePort(0)).toBe(false)
      expect(validatePort(65536)).toBe(false)
      expect(validatePort(-1)).toBe(false)
      expect(validatePort(3000.5)).toBe(false)
      expect(validatePort("invalid")).toBe(false)
      expect(validatePort("3000abc")).toBe(false)  // Should reject strings with non-digits
      expect(validatePort("abc3000")).toBe(false)  // Should reject strings with non-digits
      expect(validatePort("30.00")).toBe(false)    // Should reject decimal strings
      expect(validatePort("3000 ")).toBe(false)    // Should reject strings with spaces
      expect(validatePort(" 3000")).toBe(false)    // Should reject strings with spaces
      expect(validatePort("0x1234")).toBe(false)   // Should reject hex notation
      expect(validatePort(null)).toBe(false)
      expect(validatePort(undefined)).toBe(false)
    })
  })
})