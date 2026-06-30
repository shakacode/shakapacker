const createLazyExport = require("../../package/utils/createLazyExport")

describe("createLazyExport", () => {
  test("does not run load until the value is first read", () => {
    const load = jest.fn(() => ({ value: 42 }))

    createLazyExport(load)

    expect(load).not.toHaveBeenCalled()
  })

  test("runs load on first get and memoizes the result", () => {
    const load = jest.fn(() => ({ value: 42 }))
    const lazy = createLazyExport(load)

    const first = lazy.get()
    const second = lazy.get()

    expect(first).toStrictEqual({ value: 42 })
    expect(second).toBe(first)
    expect(load).toHaveBeenCalledTimes(1)
  })

  test("memoizes a load that returns undefined instead of re-running it", () => {
    // The `loaded` flag (not an `=== undefined` sentinel) records that load ran,
    // so a loader that legitimately yields `undefined` is cached once rather
    // than silently re-invoked — and re-running its side effects — on every read.
    const load = jest.fn(() => undefined)
    const lazy = createLazyExport(load)

    expect(lazy.get()).toBeUndefined()
    expect(lazy.get()).toBeUndefined()
    expect(load).toHaveBeenCalledTimes(1)
  })

  test("retries load on next get after load throws", () => {
    const load = jest
      .fn()
      .mockImplementationOnce(() => {
        throw new Error("transient failure")
      })
      .mockReturnValue("recovered")
    const lazy = createLazyExport(load)

    expect(() => lazy.get()).toThrow("transient failure")
    expect(lazy.get()).toBe("recovered")
    expect(load).toHaveBeenCalledTimes(2)
  })

  test("does not cache failures from load", () => {
    const load = jest.fn(() => {
      throw new Error("always fails")
    })
    const lazy = createLazyExport(load)

    expect(() => lazy.get()).toThrow("always fails")
    expect(() => lazy.get()).toThrow("always fails")
    expect(load).toHaveBeenCalledTimes(2)
  })

  test("exposes a configurable, enumerable accessor descriptor", () => {
    const lazy = createLazyExport(() => "value")

    expect(lazy.descriptor).toStrictEqual({
      configurable: true,
      enumerable: true,
      get: expect.any(Function),
      set: expect.any(Function)
    })
  })

  test("the installed property and get() share one cache", () => {
    const load = jest.fn(() => ["rule"])
    const lazy = createLazyExport(load)
    const target = {}
    Object.defineProperty(target, "rules", lazy.descriptor)

    expect(target.rules).toBe(lazy.get())
    expect(load).toHaveBeenCalledTimes(1)
  })

  test("assignment overrides the value without running load", () => {
    const load = jest.fn(() => "real")
    const lazy = createLazyExport(load)
    const target = {}
    Object.defineProperty(target, "value", lazy.descriptor)

    target.value = "override"

    expect(target.value).toBe("override")
    expect(load).not.toHaveBeenCalled()
  })

  test("assigning undefined caches it as-is without re-arming lazy loading", () => {
    const load = jest.fn(() => "real")
    const lazy = createLazyExport(load)
    const target = {}
    Object.defineProperty(target, "value", lazy.descriptor)

    target.value = "override"
    target.value = undefined

    // Assignment overrides the cache with whatever is assigned, including
    // `undefined`; it does not fall back to re-running the loader.
    expect(target.value).toBeUndefined()
    expect(load).not.toHaveBeenCalled()
  })

  test("a value-descriptor redefinition bypasses the setter and leaves the cache untouched", () => {
    const load = jest.fn(() => "real")
    const lazy = createLazyExport(load)
    const target = {}
    Object.defineProperty(target, "value", lazy.descriptor)

    Object.defineProperty(target, "value", {
      value: "data",
      writable: true,
      configurable: true
    })

    expect(target.value).toBe("data")
    // The accessor was replaced before any read, so load never ran and the
    // internal cache is still empty; get() would still lazily load.
    expect(load).not.toHaveBeenCalled()
    expect(lazy.get()).toBe("real")
    expect(load).toHaveBeenCalledTimes(1)
  })
})
