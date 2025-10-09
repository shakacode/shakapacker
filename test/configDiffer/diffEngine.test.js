const { DiffEngine } = require("../../package/configDiffer/diffEngine")

describe("DiffEngine", () => {
  describe("primitive values", () => {
    test("detects no changes when values are identical", () => {
      const engine = new DiffEngine()
      const result = engine.compare({ a: 1, b: "test" }, { a: 1, b: "test" })

      expect(result.summary.totalChanges).toBe(0)
      expect(result.summary.added).toBe(0)
      expect(result.summary.removed).toBe(0)
      expect(result.summary.changed).toBe(0)
    })

    test("detects changed values", () => {
      const engine = new DiffEngine()
      const result = engine.compare({ a: 1 }, { a: 2 })

      expect(result.summary.totalChanges).toBe(1)
      expect(result.summary.changed).toBe(1)
      expect(result.entries[0].operation).toBe("changed")
      expect(result.entries[0].path.humanPath).toBe("a")
      expect(result.entries[0].oldValue).toBe(1)
      expect(result.entries[0].newValue).toBe(2)
    })

    test("detects added values", () => {
      const engine = new DiffEngine()
      const result = engine.compare({ a: 1 }, { a: 1, b: 2 })

      expect(result.summary.totalChanges).toBe(1)
      expect(result.summary.added).toBe(1)
      expect(result.entries[0].operation).toBe("added")
      expect(result.entries[0].path.humanPath).toBe("b")
    })

    test("detects removed values", () => {
      const engine = new DiffEngine()
      const result = engine.compare({ a: 1, b: 2 }, { a: 1 })

      expect(result.summary.totalChanges).toBe(1)
      expect(result.summary.removed).toBe(1)
      expect(result.entries[0].operation).toBe("removed")
      expect(result.entries[0].path.humanPath).toBe("b")
    })
  })

  describe("nested objects", () => {
    test("detects changes in nested objects", () => {
      const engine = new DiffEngine()
      const left = { outer: { inner: { value: 1 } } }
      const right = { outer: { inner: { value: 2 } } }
      const result = engine.compare(left, right)

      expect(result.summary.totalChanges).toBe(1)
      expect(result.summary.changed).toBe(1)
      expect(result.entries[0].path.humanPath).toBe("outer.inner.value")
    })

    test("detects added nested properties", () => {
      const engine = new DiffEngine()
      const left = { outer: { inner: {} } }
      const right = { outer: { inner: { newProp: "value" } } }
      const result = engine.compare(left, right)

      expect(result.summary.totalChanges).toBe(1)
      expect(result.summary.added).toBe(1)
      expect(result.entries[0].path.humanPath).toBe("outer.inner.newProp")
    })
  })

  describe("arrays", () => {
    test("detects changes in array elements", () => {
      const engine = new DiffEngine()
      const result = engine.compare({ arr: [1, 2, 3] }, { arr: [1, 5, 3] })

      expect(result.summary.totalChanges).toBe(1)
      expect(result.summary.changed).toBe(1)
      expect(result.entries[0].path.humanPath).toBe("arr.[1]")
    })

    test("detects added array elements", () => {
      const engine = new DiffEngine()
      const result = engine.compare({ arr: [1, 2] }, { arr: [1, 2, 3] })

      expect(result.summary.totalChanges).toBe(1)
      expect(result.summary.added).toBe(1)
      expect(result.entries[0].path.humanPath).toBe("arr.[2]")
    })

    test("detects removed array elements", () => {
      const engine = new DiffEngine()
      const result = engine.compare({ arr: [1, 2, 3] }, { arr: [1, 2] })

      expect(result.summary.totalChanges).toBe(1)
      expect(result.summary.removed).toBe(1)
      expect(result.entries[0].path.humanPath).toBe("arr.[2]")
    })
  })

  describe("options", () => {
    test("respects includeUnchanged option", () => {
      const engine = new DiffEngine({ includeUnchanged: true })
      const result = engine.compare({ a: 1, b: 2 }, { a: 1, b: 3 })

      expect(result.summary.unchanged).toBe(1)
      expect(result.entries.some((e) => e.operation === "unchanged")).toBe(true)
    })

    test("respects ignoreKeys option", () => {
      const engine = new DiffEngine({ ignoreKeys: ["ignored"] })
      const result = engine.compare(
        { a: 1, ignored: "old" },
        { a: 1, ignored: "new" }
      )

      expect(result.summary.totalChanges).toBe(0)
    })

    test("respects ignorePaths option", () => {
      const engine = new DiffEngine({ ignorePaths: ["nested.ignored"] })
      const result = engine.compare(
        { nested: { ignored: "old", kept: 1 } },
        { nested: { ignored: "new", kept: 2 } }
      )

      expect(result.summary.totalChanges).toBe(1)
      expect(result.entries[0].path.humanPath).toBe("nested.kept")
    })

    test("supports wildcard in ignorePaths", () => {
      const engine = new DiffEngine({ ignorePaths: ["plugins.*"] })
      const result = engine.compare(
        { plugins: { a: 1, b: 2 }, other: 1 },
        { plugins: { a: 99, b: 99 }, other: 2 }
      )

      expect(result.summary.totalChanges).toBe(1)
      expect(result.entries[0].path.humanPath).toBe("other")
    })

    test("respects maxDepth option", () => {
      const engine = new DiffEngine({ maxDepth: 1 })
      const result = engine.compare(
        { a: { b: { c: 1 } } },
        { a: { b: { c: 2 } } }
      )

      expect(result.summary.totalChanges).toBe(0)
    })
  })

  describe("special types", () => {
    test("handles functions", () => {
      const engine = new DiffEngine()
      const fn1 = () => "test"
      const fn2 = () => "test"
      const result = engine.compare({ fn: fn1 }, { fn: fn2 })

      expect(result.summary.totalChanges).toBe(0)
    })

    test("detects different functions", () => {
      const engine = new DiffEngine()
      const fn1 = () => "test1"
      const fn2 = () => "test2"
      const result = engine.compare({ fn: fn1 }, { fn: fn2 })

      expect(result.summary.totalChanges).toBe(1)
      expect(result.summary.changed).toBe(1)
    })

    test("handles RegExp", () => {
      const engine = new DiffEngine()
      const result = engine.compare({ re: /test/i }, { re: /test/i })

      expect(result.summary.totalChanges).toBe(0)
    })

    test("detects different RegExp", () => {
      const engine = new DiffEngine()
      const result = engine.compare({ re: /test/i }, { re: /other/i })

      expect(result.summary.totalChanges).toBe(1)
    })

    test("handles Date objects", () => {
      const engine = new DiffEngine()
      const date1 = new Date("2025-01-01")
      const date2 = new Date("2025-01-01")
      const result = engine.compare({ date: date1 }, { date: date2 })

      expect(result.summary.totalChanges).toBe(0)
    })

    test("detects different Date objects", () => {
      const engine = new DiffEngine()
      const date1 = new Date("2025-01-01")
      const date2 = new Date("2025-01-02")
      const result = engine.compare({ date: date1 }, { date: date2 })

      expect(result.summary.totalChanges).toBe(1)
    })
  })

  describe("metadata", () => {
    test("includes comparison timestamp", () => {
      const engine = new DiffEngine()
      const result = engine.compare({ a: 1 }, { a: 1 })

      expect(result.metadata.comparedAt).toBeDefined()
      expect(new Date(result.metadata.comparedAt)).toBeInstanceOf(Date)
    })

    test("includes custom metadata", () => {
      const engine = new DiffEngine()
      const result = engine.compare({ a: 1 }, { a: 1 }, { custom: "data" })

      expect(result.metadata.custom).toBe("data")
    })
  })
})
