const { DiffFormatter } = require("../../package/configDiffer/formatter")

describe("DiffFormatter", () => {
  const mockResult = {
    summary: {
      totalChanges: 3,
      added: 1,
      removed: 1,
      changed: 1
    },
    entries: [
      {
        operation: "added",
        path: { path: ["newKey"], humanPath: "newKey" },
        newValue: "newValue",
        valueType: "string"
      },
      {
        operation: "removed",
        path: { path: ["oldKey"], humanPath: "oldKey" },
        oldValue: "oldValue",
        valueType: "string"
      },
      {
        operation: "changed",
        path: { path: ["changedKey"], humanPath: "changedKey" },
        oldValue: "oldValue",
        newValue: "newValue",
        valueType: "string"
      }
    ],
    metadata: {
      comparedAt: "2025-01-01T00:00:00.000Z",
      leftFile: "config1.yaml",
      rightFile: "config2.yaml"
    }
  }

  describe("formatJson", () => {
    test("formats result as JSON", () => {
      const formatter = new DiffFormatter()
      const output = formatter.formatJson(mockResult)

      const parsed = JSON.parse(output)
      expect(parsed.summary.totalChanges).toBe(3)
      expect(parsed.entries).toHaveLength(3)
      expect(parsed.metadata.comparedAt).toBeDefined()
    })
  })

  describe("formatYaml", () => {
    test("formats result as YAML", () => {
      const formatter = new DiffFormatter()
      const output = formatter.formatYaml(mockResult)

      expect(output).toContain("metadata:")
      expect(output).toContain("summary:")
      expect(output).toContain("totalChanges: 3")
      expect(output).toContain("added:")
      expect(output).toContain("removed:")
      expect(output).toContain("changed:")
    })
  })

  describe("formatSummary", () => {
    test("formats summary with counts", () => {
      const formatter = new DiffFormatter()
      const output = formatter.formatSummary(mockResult)

      expect(output).toContain("3 changes")
      expect(output).toContain("+1")
      expect(output).toContain("-1")
      expect(output).toContain("~1")
    })

    test("shows success message when no changes", () => {
      const formatter = new DiffFormatter()
      const noChanges = {
        ...mockResult,
        summary: { totalChanges: 0, added: 0, removed: 0, changed: 0 },
        entries: []
      }

      const output = formatter.formatSummary(noChanges)

      expect(output).toContain("No differences found")
      expect(output).toContain("✅")
    })
  })

  describe("formatDetailed", () => {
    test("includes all sections", () => {
      const formatter = new DiffFormatter()
      const output = formatter.formatDetailed(mockResult)

      expect(output).toContain("Webpack/Rspack Configuration Comparison")
      expect(output).toContain("Comparing:")
      expect(output).toContain("config1.yaml")
      expect(output).toContain("config2.yaml")
      expect(output).toContain("Legend:")
    })

    test("shows changes with symbols", () => {
      const formatter = new DiffFormatter()
      const output = formatter.formatDetailed(mockResult)

      expect(output).toContain("[+]")
      expect(output).toContain("[-]")
      expect(output).toContain("[~]")
    })

    test("formats entry details", () => {
      const formatter = new DiffFormatter()
      const output = formatter.formatDetailed(mockResult)

      expect(output).toContain("newKey")
      expect(output).toContain("oldKey")
      expect(output).toContain("changedKey")
    })

    test("shows values with file labels for changed entries", () => {
      const formatter = new DiffFormatter()
      const output = formatter.formatDetailed(mockResult)

      expect(output).toContain("Values:")
      // Should have left/right labels or extracted short names
      expect(output).toMatch(/(left|right|config\d):/i)
    })

    test("does not leave numbering gaps when unchanged entries are hidden", () => {
      const formatter = new DiffFormatter()
      const resultWithUnchanged = {
        summary: { totalChanges: 1, added: 0, removed: 0, changed: 1 },
        entries: [
          {
            operation: "unchanged",
            path: { path: ["a"], humanPath: "a" },
            oldValue: 1,
            newValue: 1,
            valueType: "number"
          },
          {
            operation: "changed",
            path: { path: ["b"], humanPath: "b" },
            oldValue: 1,
            newValue: 2,
            valueType: "number"
          }
        ],
        metadata: mockResult.metadata
      }

      const output = formatter.formatDetailed(resultWithUnchanged)

      expect(output).toContain("1. [~] b")
      expect(output).not.toContain("2. [~] b")
    })

    test("extracts short labels from Windows-style paths", () => {
      const formatter = new DiffFormatter()
      const windowsPathsResult = {
        ...mockResult,
        metadata: {
          ...mockResult.metadata,
          leftFile: "C:\\\\repo\\\\webpack-development-client.yaml",
          rightFile: "C:\\\\repo\\\\webpack-production-client.yaml"
        }
      }

      const output = formatter.formatDetailed(windowsPathsResult)

      expect(output).toContain("dev-client:")
      expect(output).toContain("prod-client:")
    })

    test("uses parent documentation for array-indexed paths", () => {
      const formatter = new DiffFormatter()
      const arrayPathResult = {
        summary: { totalChanges: 1, added: 0, removed: 0, changed: 1 },
        entries: [
          {
            operation: "changed",
            path: {
              path: ["optimization", "minimizer", "[0]"],
              humanPath: "optimization.minimizer.[0]"
            },
            oldValue: "TerserPlugin",
            newValue: "EsbuildPlugin",
            valueType: "string"
          }
        ],
        metadata: mockResult.metadata
      }

      const output = formatter.formatDetailed(arrayPathResult)

      expect(output).toContain("Array of plugins to use for minification.")
      expect(output).toContain("Documentation:")
    })
  })
})
