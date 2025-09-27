# Shakapacker v9 TODO List

## CSS Modules Configuration Alignment

### Problem
Current CSS modules configuration causes TypeScript/webpack warnings because of default vs named export mismatch.

### Current Behavior (v8)
- CSS modules use default export: `import styles from './styles.module.css'`
- This causes warnings but works at runtime
- Warning example: `export 'default' (imported as 'style') was not found in './HelloWorld.module.css'`

### Proposed v9 Change
Align with Next.js and modern tooling by using named exports:

1. **Update css-loader configuration:**
```javascript
{
  loader: 'css-loader',
  options: {
    modules: {
      namedExport: true,
      exportLocalsConvention: 'camelCase'
    }
  }
}
```

2. **Update TypeScript types:**
- Ensure proper typing for CSS modules with named exports
- May need to update or generate `.d.ts` files for CSS modules

3. **Migration guide for users:**
- Document the breaking change
- Provide codemod or migration script to update imports from:
  ```javascript
  import styles from './styles.module.css'
  styles.className
  ```
  to:
  ```javascript
  import * as styles from './styles.module.css'
  // or
  import { className } from './styles.module.css'
  ```

### Benefits
- Eliminates webpack/TypeScript warnings
- Better tree-shaking potential
- More explicit about what CSS classes are being used
- Easier interoperability with frameworks that support named exports

### Implementation Notes
- This is a BREAKING CHANGE and appropriate for major version bump
- Need to test with both webpack and rspack
- Consider providing a compatibility mode via configuration option

---

## Related Issues from PR #597

### React Component Not Rendering (spec/dummy) - CRITICAL
- **Issue**: React component not rendering at all with react_on_rails 16.1
- **Symptoms**:
  - Component should render "Hello, Stranger!" but nothing appears
  - Input field not rendered, making interactive test fail
  - Only the static H1 "Hello, World!" is visible
  - **ISSUE PERSISTS EVEN WITH REACT 18.3.1**
- **Temporary Fix**:
  - Downgraded to React 18.3.1 (from 19.1.1) but issue persists
  - Keeping prerender: true (SSR enabled but not working)
  - Skipped interactive component test
- **Root Cause**: react_on_rails 16.1 configuration or integration issue
  - Not a React version issue (happens with both v18 and v19)
  - Likely missing configuration or initialization
  - Server bundle builds but component doesn't render
- **Action Required**:
  - Investigate react_on_rails 16.1 setup requirements for Rails 8
  - Check if additional configuration is needed for SSR
  - Verify JavaScript pack is being loaded correctly
  - Consider creating minimal reproduction case

### Test Infrastructure
- Successfully implemented dual bundler support (webpack/rspack)
- test-bundler script working well with status command
- Consider adding more comprehensive tests for both bundlers