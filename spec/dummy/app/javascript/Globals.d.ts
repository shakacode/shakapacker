declare module "*.module.css" {
  // Support for named exports (v9 default)
  const classes: { readonly [key: string]: string };
  export = classes;
}
declare module "*.module.scss" {
  // Support for named exports (v9 default)
  const classes: { readonly [key: string]: string };
  export = classes;
}
declare module "*.svg";
