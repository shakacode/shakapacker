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
- Alignment with Next.js and other modern frameworks
- More explicit about what CSS classes are being used

### Implementation Notes
- This is a BREAKING CHANGE and appropriate for major version bump
- Need to test with both webpack and rspack
- Consider providing a compatibility mode via configuration option

---

## Related Issues from PR #597

### React Component Props Not Rendering (spec/dummy)
- The test expects "Hello, Stranger!" but component shows "Hello, World!"
- Controller passes `{ name: "Stranger" }` as props
- Likely SSR issue with React 19 and react_on_rails 16.1
- Need to investigate server-side rendering compatibility

### Test Infrastructure
- Successfully implemented dual bundler support (webpack/rspack)
- test-bundler script working well with status command
- Consider adding more comprehensive tests for both bundlers