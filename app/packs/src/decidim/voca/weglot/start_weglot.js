import waitForWeglot from "./wait_for_weglot";

function config() {
  return window.VocaWeglotConfig;
}

export default async function startWeglot() {
  const { enabled, api_key, default_language } = config();
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
    switchers: [],
    translate_search: true,
    search_forms: "#form-search_topbar",
    search_parameter: "term",
    auto_switch: true,
    auto_switch_fallback: default_language,
    hide_switcher: true,
  });
}
