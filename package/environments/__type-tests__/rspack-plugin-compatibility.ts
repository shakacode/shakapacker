/**
 * Compile-time type tests for RspackPlugin backward compatibility
 * This file ensures that RspackPlugin is correctly aliased to RspackPluginInstance
 * and maintains backward compatibility for existing consumers.
 *
 * These tests will fail at compile time if the types are not compatible.
 */

import type { RspackPlugin, RspackPluginInstance } from "../types"

// Test 1: RspackPlugin should be assignable to RspackPluginInstance
const testPluginToInstance = (plugin: RspackPlugin): RspackPluginInstance =>
  plugin

// Test 2: RspackPluginInstance should be assignable to RspackPlugin
const testInstanceToPlugin = (instance: RspackPluginInstance): RspackPlugin =>
  instance

// Test 3: Array compatibility
const testArrayCompatibility = (
  plugins: RspackPlugin[]
): RspackPluginInstance[] => plugins
const testArrayCompatibilityReverse = (
  instances: RspackPluginInstance[]
): RspackPlugin[] => instances

// Test 4: Optional parameter compatibility
const testOptionalParam = (
  plugin?: RspackPlugin
): RspackPluginInstance | undefined => plugin
const testOptionalParamReverse = (
  instance?: RspackPluginInstance
): RspackPlugin | undefined => instance

// Export a dummy value to make this a module
export const __typeTestsComplete = true
