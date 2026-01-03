/**
 * Shared environment variable filtering logic for webpack and rspack plugins.
 *
 * SECURITY: This module ensures only allowlisted environment variables are
 * exposed to client-side JavaScript bundles, preventing accidental leakage
 * of secrets like DATABASE_URL, API keys, etc.
 */

/**
 * Allowlist of environment variables that are safe to expose to client-side JavaScript.
 *
 * SECURITY: Never add sensitive variables like DATABASE_URL, API keys, or secrets.
 * These values are embedded directly into the JavaScript bundle and are publicly visible.
 *
 * Users can extend this list via SHAKAPACKER_ENV_VARS environment variable (comma-separated)
 * or by customizing their webpack/rspack config.
 */
export const DEFAULT_ALLOWED_ENV_VARS = [
  "NODE_ENV",
  "RAILS_ENV",
  "WEBPACK_SERVE"
] as const

/**
 * Pattern to detect potentially sensitive environment variable names.
 * Used to warn developers if they accidentally expose secrets via SHAKAPACKER_ENV_VARS.
 */
const DANGEROUS_PATTERNS =
  /SECRET|PASSWORD|KEY|TOKEN|CREDENTIAL|DATABASE|DB_|AWS_|PRIVATE|AUTH/i

/**
 * Gets the list of environment variables to expose to client-side code.
 * Combines default allowed vars with any user-specified vars from SHAKAPACKER_ENV_VARS.
 */
export const getAllowedEnvVars = (): string[] => {
  const allowed: string[] = [...DEFAULT_ALLOWED_ENV_VARS]

  // Allow users to specify additional env vars via SHAKAPACKER_ENV_VARS
  const userVars = process.env.SHAKAPACKER_ENV_VARS
  if (userVars) {
    const additionalVars = userVars
      .split(",")
      .map((v) => v.trim())
      .filter(Boolean)

    // Warn about potentially dangerous variable names
    additionalVars.forEach((varName) => {
      if (DANGEROUS_PATTERNS.test(varName)) {
        console.warn(
          `⚠️  [SHAKAPACKER SECURITY WARNING] "${varName}" matches a sensitive pattern. ` +
            `Ensure this variable is safe to expose in client-side JavaScript bundles.`
        )
      }
    })

    allowed.push(...additionalVars)
  }

  return allowed
}

/**
 * Builds a filtered environment object containing only allowed variables.
 * Returns an object with variable names as keys and their values.
 * Uses null as default for missing variables (webpack/rspack treat null as optional).
 */
export const getFilteredEnv = (): Record<string, string | null> => {
  const allowedVars = getAllowedEnvVars()
  const filtered: Record<string, string | null> = {}

  for (const varName of allowedVars) {
    // Use null as default for missing vars - webpack/rspack treat null as optional
    // (undefined would cause them to throw if the var is used but not set)
    filtered[varName] = process.env[varName] ?? null
  }

  return filtered
}
