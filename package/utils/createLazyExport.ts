/**
 * Builds a lazily-loaded property for an exports object.
 *
 * The first `get` runs `load` and caches the result. Direct assignment runs
 * the setter and overrides the cached value; assigning `undefined` resets to
 * lazy loading rather than caching a permanently-undefined value the getter
 * would then return silently. Redefining the property with a value descriptor
 * (`Object.defineProperty(target, key, { value })`) bypasses the setter,
 * leaving the cache untouched.
 *
 * Returns the getter (for internal callers that need the value without going
 * through the property) plus a configurable, enumerable accessor descriptor
 * to install with `Object.defineProperty`.
 */
const createLazyExport = <T>(
  load: () => T
): { get: () => T; descriptor: PropertyDescriptor } => {
  let cached: T | undefined

  const get = (): T => {
    if (cached === undefined) {
      cached = load()
    }

    return cached
  }

  return {
    get,
    descriptor: {
      configurable: true,
      enumerable: true,
      get,
      set(value: T | undefined) {
        cached = value
      }
    }
  }
}

export = createLazyExport
