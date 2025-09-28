# Investigation: Can we remove babel from peerDependencies?

## Summary

**Yes, babel can and should be removed from peerDependencies.** Shakapacker v9 already supports multiple JavaScript transpilers (babel, swc, esbuild), and babel is no longer a mandatory requirement for the package to function.

## Current State

### Babel in peerDependencies (latest published version)
The current npm package lists these babel-related peer dependencies:
- `@babel/core: ^7.17.9`
- `@babel/runtime: ^7.17.9`
- `@babel/preset-env: ^7.16.11`
- `@babel/plugin-transform-runtime: ^7.17.0`
- `babel-loader: ^8.2.4 || ^9.0.0 || ^10.0.0`

### How Babel is Used

1. **Conditional Loading**: The code uses `loaderMatches()` helper to conditionally load babel-loader only when `javascript_transpiler` is set to 'babel'
2. **Alternative Transpilers**: Shakapacker supports three transpilers:
   - `babel` (default for webpack)
   - `swc` (default for rspack, 20x faster than babel)
   - `esbuild`
3. **Installation Template**: The installer already conditionally installs babel dependencies only when `USE_BABEL_PACKAGES` env var is set

## Evidence Supporting Removal

### 1. Configuration Design
- The config system allows selecting transpilers via `javascript_transpiler` option
- Default is 'babel' for webpack, but 'swc' for rspack
- Each transpiler loader is conditionally loaded based on configuration

### 2. Documentation Already Discourages Babel
From `docs/peer-dependencies.md`:
```markdown
## Babel (avoid if at all possible)
```

### 3. Installation Process is Already Conditional
- `lib/install/template.rb` uses `USE_BABEL_PACKAGES` environment variable
- Babel dependencies are in separate `lib/install/package.json` section
- Installation can skip babel packages entirely

### 4. Code Architecture Supports Optional Babel
- `package/rules/babel.js` only loads when `javascript_transpiler === 'babel'`
- The `loaderMatches()` helper validates the loader exists before using it
- Alternative transpilers (swc, esbuild) have their own rule files

## Recommended Changes

### 1. Remove from peerDependencies
Remove all babel-related entries from the published package's peerDependencies.

### 2. Update Installation Logic
Modify `lib/install/template.rb` to:
- Check if user wants babel transpiler
- Only install babel dependencies when explicitly requested or when babel is configured

### 3. Update Documentation
- Clearly document that babel is optional
- Provide migration guide for users switching from babel to swc/esbuild
- Update peer-dependencies.md to reflect babel as optional

### 4. Consider Making SWC the Default
Since SWC is:
- 20x faster than babel
- Already the default for rspack
- A drop-in replacement for babel
Consider making it the default for webpack too in v9.

## Benefits of Removal

1. **Reduced Dependencies**: Users who use swc/esbuild won't need babel packages
2. **Clearer Intent**: Makes it obvious that babel is optional
3. **Performance Push**: Encourages users to adopt faster transpilers
4. **Smaller Install Size**: Babel and its dependencies are quite large
5. **Simpler Setup**: New projects can start without babel complexity

## Migration Path

For existing users:
1. Those using babel will need to manually install babel dependencies
2. Provide clear error message when babel-loader is missing but configured
3. Update installation generator to ask which transpiler to use

## Conclusion

Removing babel from peerDependencies aligns with the project's direction toward modern, faster transpilers while maintaining backward compatibility through optional installation. The architecture already supports this change with minimal code modifications needed.