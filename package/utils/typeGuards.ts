import { Config, DevServerConfig, YamlConfig } from "../types"

// Cache for validated configs in production
const validatedConfigs = new WeakMap<object, boolean>()

// Only validate in development or when explicitly enabled
const shouldValidate = process.env.NODE_ENV !== 'production' || process.env.SHAKAPACKER_STRICT_VALIDATION === 'true'

/**
 * Type guard to validate Config object at runtime
 * In production, caches results for performance unless SHAKAPACKER_STRICT_VALIDATION is set
 */
export function isValidConfig(obj: unknown): obj is Config {
  if (typeof obj !== 'object' || obj === null) {
    return false
  }

  // Quick return for production with cached results
  if (!shouldValidate && validatedConfigs.has(obj as object)) {
    return validatedConfigs.get(obj as object) as boolean
  }

  const config = obj as Record<string, unknown>
  
  // Check required string fields
  const requiredStringFields = [
    'source_path',
    'source_entry_path', 
    'public_root_path',
    'public_output_path',
    'cache_path',
    'javascript_transpiler'
  ]
  
  for (const field of requiredStringFields) {
    if (typeof config[field] !== 'string') {
      return false
    }
  }
  
  // Check required boolean fields
  const requiredBooleanFields = [
    'nested_entries',
    'css_extract_ignore_order_warnings',
    'webpack_compile_output',
    'shakapacker_precompile',
    'cache_manifest',
    'ensure_consistent_versioning',
    'useContentHash',
    'compile'
  ]
  
  for (const field of requiredBooleanFields) {
    if (typeof config[field] !== 'boolean') {
      return false
    }
  }
  
  // Check arrays
  if (!Array.isArray(config.additional_paths)) {
    return false
  }
  
  // Check optional fields
  if (config.dev_server !== undefined && !isValidDevServerConfig(config.dev_server)) {
    return false
  }
  
  if (config.integrity !== undefined) {
    const integrity = config.integrity as Record<string, unknown>
    if (typeof integrity.enabled !== 'boolean' || 
        typeof integrity.cross_origin !== 'string') {
      return false
    }
  }
  
  const result = true
  
  // Cache result in production
  if (!shouldValidate) {
    validatedConfigs.set(obj as object, result)
  }
  
  return result
}

/**
 * Type guard to validate DevServerConfig object at runtime
 * In production, performs minimal validation for performance
 */
export function isValidDevServerConfig(obj: unknown): obj is DevServerConfig {
  if (typeof obj !== 'object' || obj === null) {
    return false
  }
  
  // In production, skip deep validation unless explicitly enabled
  if (!shouldValidate) {
    return true
  }
  
  const config = obj as Record<string, unknown>
  
  // All fields are optional, just check types if present
  if (config.hmr !== undefined && 
      typeof config.hmr !== 'boolean' && 
      config.hmr !== 'only') {
    return false
  }
  
  if (config.port !== undefined && 
      typeof config.port !== 'number' && 
      typeof config.port !== 'string' &&
      config.port !== 'auto') {
    return false
  }
  
  return true
}

/**
 * Type guard to validate YamlConfig structure
 * In production, performs minimal validation for performance
 */
export function isValidYamlConfig(obj: unknown): obj is YamlConfig {
  if (typeof obj !== 'object' || obj === null) {
    return false
  }
  
  // In production, skip deep validation unless explicitly enabled
  if (!shouldValidate) {
    return true
  }
  
  const config = obj as Record<string, unknown>
  
  // Each key should map to an object
  for (const env of Object.keys(config)) {
    if (typeof config[env] !== 'object' || config[env] === null) {
      return false
    }
  }
  
  return true
}

/**
 * Validates partial config used for merging
 * Ensures that if fields are present, they have the correct types
 * In production, performs minimal validation for performance
 */
export function isPartialConfig(obj: unknown): obj is Partial<Config> {
  if (typeof obj !== 'object' || obj === null) {
    return false
  }
  
  // In production, skip deep validation unless explicitly enabled
  if (!shouldValidate) {
    return true
  }
  
  const config = obj as Record<string, unknown>
  
  // Check string fields if present
  const stringFields = [
    'source_path', 'source_entry_path', 'public_root_path',
    'public_output_path', 'cache_path', 'javascript_transpiler'
  ]
  
  for (const field of stringFields) {
    if (field in config && typeof config[field] !== 'string') {
      return false
    }
  }
  
  // Check boolean fields if present
  const booleanFields = [
    'nested_entries', 'css_extract_ignore_order_warnings',
    'webpack_compile_output', 'shakapacker_precompile',
    'cache_manifest', 'ensure_consistent_versioning'
  ]
  
  for (const field of booleanFields) {
    if (field in config && typeof config[field] !== 'boolean') {
      return false
    }
  }
  
  // Check arrays if present
  if ('additional_paths' in config && !Array.isArray(config.additional_paths)) {
    return false
  }
  
  return true
}

/**
 * Creates a validation error with helpful context
 */
export function createConfigValidationError(
  configPath: string,
  environment: string,
  details?: string
): Error {
  const message = `Invalid configuration in ${configPath} for environment '${environment}'`
  return new Error(details ? `${message}: ${details}` : message)
}

