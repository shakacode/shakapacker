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
  })
})
