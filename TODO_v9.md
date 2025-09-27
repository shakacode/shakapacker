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
- **Issue**: React component not rendering at all with React 19 and react_on_rails 16.1
- **Symptoms**:
  - Component should render "Hello, Stranger!" but nothing appears
  - Input field not rendered, making interactive test fail
  - Only the static H1 "Hello, World!" is visible
- **Temporary Fix**:
  - Keeping prerender: true (SSR works but client hydration may be broken)
  - Skipped interactive component test
- **Root Cause**: Likely compatibility issue between:
  - React ^19.1.1
  - react-dom ^19.1.1
  - react-on-rails ^16.1.0
  - Rails ~8.0.3
- **Action Required**:
  - Investigate react_on_rails 16.1 SSR with React 19
  - May need to downgrade React or update react_on_rails configuration
  - Check if server bundle is being executed properly

### Test Infrastructure
- Successfully implemented dual bundler support (webpack/rspack)
- test-bundler script working well with status command
- Consider adding more comprehensive tests for both bundlers