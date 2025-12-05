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
    console.log("Voca Weglot: error initializing, skipping");
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
      // Modals and dialogs
      "#loginModal",
      "#confirm-modal",
      "#authorizationModal",
      "#socialShare",
      "#dc-modal",
      "#noeffe-tooltip",
      "#external-domain-warning",
      "#flag-modal",
      "#QRCodeDialog",
      "#exit-proposal-notification",
      ".calendar-modal",
      "#dialog-title-renew-modal",
      "#close-debate",
      "#show-email-modal",
      ".flag-user-modal",
      "#sign-up-newsletter-modal",
      ".meeting__registration-modal",
      "#RegistrationQRCodeDialog",
      ".meeting__cancelation-modal",
      ".upload-modal",
      "#fingerprint-modal",
      "#messageErrorModal",
      "#process-steps-modal",
      "#budget-confirm-current-order",
      "#photo-modal",
      "#renew-modal",
      "#exit-notification",
      ".conference__registration-modal",
      "#dialog-title-budget-modal-info",
      "#timeoutModal",
      ".login__box",
      // Ajax content
      "#activities-container",
      ".external-domain-warning-container",
      "#processes-grid",
      "#parent-assemblies",
      "#order-total-budget",
      "#projects",
      ".comments-count",
      "#consultations",
      ".button-group",
      "#results",
      ".search-filters",
      "#activities-container",
      "#urlShareTest",
      "#elections",
      "#votings",
      ".dropdown.menu",
      "#initiatives",
      "#meetings",
      "#admin-meeting-poll-aside",
      "#meeting-poll-aside",
      "#collaborative_drafts",
      "#remaining-votes-count",
      "#proposals",
      "#sortitions",
      ".choose-template-preview",    
    ].map((selector) => ({
      type: 1,
      selector: selector,
      attribute: "textContent",
    })),
  });
}
