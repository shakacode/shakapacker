/**
 * Builds a lazily-loaded property for an exports object.
 *
 * The first `get` runs `load` and caches the result. A dedicated `loaded` flag
 * (rather than an `=== undefined` sentinel) tracks whether the value has been
 * computed, so a `load` that legitimately returns `undefined` is cached like
 * any other value instead of silently re-running on every access. Direct
 * assignment runs the setter and overrides the cached value; assigning
 * `undefined` resets to lazy loading rather than caching a permanently-undefined
 * value the getter would then return silently. Redefining the property with a
 * value descriptor (`Object.defineProperty(target, key, { value })`) bypasses
 * the setter, leaving the cache untouched.
 *
 * Returns the getter (for internal callers that need the value without going
 * through the property) plus a configurable, enumerable accessor descriptor to
 * install with `Object.defineProperty`. The descriptor type is a literal so the
 * configurable/enumerable/accessor invariants are enforced at the call sites
 * rather than erased to the loose built-in `PropertyDescriptor`.
 */
const createLazyExport = <T>(
  load: () => T
): {
  get: () => T
  descriptor: {
    configurable: true
    enumerable: true
    get: () => T
    set: (value: T | undefined) => void
  }
} => {
  let cached: T | undefined
  let loaded = false

  const get = (): T => {
    if (!loaded) {
      cached = load()
      loaded = true
    }

    return cached as T
  }

  return {
    get,
    descriptor: {
      configurable: true,
      enumerable: true,
      get,
      set(value: T | undefined) {
        if (value === undefined) {
          cached = undefined
          loaded = false
        } else {
          cached = value
          loaded = true
        }
      }
    }
  }
}

export = createLazyExport
