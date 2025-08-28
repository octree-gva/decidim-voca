import waitForWeglot from "./wait_for_weglot";

function config() {
  return window.VocaWeglotConfig;
}

export default async function startWeglot() {
  const { enabled, api_key, default_language, enable_cache } = config();
  if (!enabled || !api_key) {
    console.log("Voca Weglot: skipping");
    return;
  }
  try {
    await waitForWeglot();
  } catch (e) {
    console.log("Voca Weglot: skipping");
    return;
  }

  window.Weglot.initialize({
    api_key,
    translate_search: true,
    cache: enable_cache,
    search_forms: "#form-search_topbar",
    search_parameter: "term",
    hide_switcher: true,
    auto_switch: true,
    auto_switch_fallback: default_language
  });
}
