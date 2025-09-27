declare module "*.module.css" {
  // v9: TypeScript definition for CSS modules
  // Uses CommonJS-style export for compatibility with webpack's namedExport: true
  // This allows namespace imports: import * as styles from './styles.module.css'
  const classes: { readonly [key: string]: string };
  export = classes;
}
declare module "*.module.scss" {
  // v9: TypeScript definition for CSS modules
  // Uses CommonJS-style export for compatibility with webpack's namedExport: true
  // This allows namespace imports: import * as styles from './styles.module.scss'
  const classes: { readonly [key: string]: string };
  export = classes;
}
declare module "*.svg";
