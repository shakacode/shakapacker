declare module '*.module.css' {
  // v9: css-loader with namedExport: true generates individual named exports
  // TypeScript can't determine the exact export names at compile time,
  // so we use this declaration to allow namespace imports.
  // Usage: import * as styles from './styles.module.css'
  // Note: Default imports (import styles from '...') will NOT work
  const classes: { readonly [key: string]: string }
  export = classes
}
declare module '*.module.scss' {
  // v9: css-loader with namedExport: true generates individual named exports
  // TypeScript can't determine the exact export names at compile time,
  // so we use this declaration to allow namespace imports.
  // Usage: import * as styles from './styles.module.scss'
  // Note: Default imports (import styles from '...') will NOT work
  const classes: { readonly [key: string]: string }
  export = classes
}
declare module '*.svg'
