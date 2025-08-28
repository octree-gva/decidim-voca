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
    cache: enable_cache,
    translate_search: true,
    search_forms: "#form-search_topbar",
    search_parameter: "term",
    wait_transition: true,
    hide_switcher: true,
    auto_switch: true,
    auto_switch_fallback: default_language,
    extra_definitions: [
      ".decidimGeo__drawer__listCardTitle",
      ".decidimGeo__drawer__listCardTxt",
      ".decidimGeo__drawer__listCardType",
      ".decidimGeo__drawer__listCardTitle",
      ".decidimGeo__drawer__listCardDescription",
      ".decidimGeo__drawer__viewBtn",
      ".decidimGeo__drawerHeader__drawerToggle",
      ".decidimGeo__filterModal__label",
      ".decidimGeo__filterModal__select",
      ".decidimGeo__filterModal__resetBtn",
      ".decidimGeo__filterModal__applyBtn",
      ".decidimGeo__container",
    ].map((selector) => ({
      type: 1,
      selector: selector,
      attribute: "textContent",
    })),
  });
}
