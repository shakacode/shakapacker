import type { Configuration } from "webpack";
import config from "./config";
import devServer from "./dev_server";
import { moduleExists, canProcess } from "./utils/helpers";
import inliningCss from "./utils/inliningCss";
declare const env: any;
declare const baseConfig: any;
declare const rules: any;
declare const generateWebpackConfig: (extraConfig?: Configuration, ...extraArgs: unknown[]) => Configuration;
export { config, // shakapacker.yml
devServer, generateWebpackConfig, baseConfig, env, rules, moduleExists, canProcess, inliningCss };
export * from "webpack-merge";
//# sourceMappingURL=index.d.ts.map