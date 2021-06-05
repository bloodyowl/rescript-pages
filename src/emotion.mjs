import createEmotion from "@emotion/css/create-instance/dist/emotion-css-create-instance.esm.js";

let {
  cache,
  css,
  cx,
  flush,
  getRegisteredStyles,
  hydrate,
  injectGlobal,
  keyframes,
  merge,
  sheet,
} = createEmotion({ key: "rpcss" });

export {
  cache,
  css,
  cx,
  flush,
  getRegisteredStyles,
  hydrate,
  injectGlobal,
  keyframes,
  merge,
  sheet,
};
