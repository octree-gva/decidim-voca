/**
 * Build-time gated console helpers for decidim-voca packs.
 * Production ships silent unless VOCA_JS_DEBUG=1 at webpack compile.
 */
const enabled =
  process.env.NODE_ENV !== "production" || process.env.VOCA_JS_DEBUG === "1";

export const log = (...args) => {
  if (enabled) {
    console.log(...args);
  }
};

export const warn = (...args) => {
  if (enabled) {
    console.warn(...args);
  }
};

export const error = (...args) => {
  if (enabled) {
    console.error(...args);
  }
};
