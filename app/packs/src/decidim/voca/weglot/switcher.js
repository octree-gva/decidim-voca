export default async function switcher() {
  const searchContainer = document.querySelector(
    ".main-footer__language-container.voca-js--weglot-locale-switcher"
  );
  if (!searchContainer || searchContainer.length === 0) {
    return;
  }
  const WeglotInstance = window.Weglot
  if (!WeglotInstance) {
    return;
  }

  const currentLang = WeglotInstance.getCurrentLang();
  const currentLanguageName = WeglotInstance.getLanguageName(currentLang);
  const button = searchContainer.querySelector(
    "main-footer__language-trigger"
  );
  button.textContent = currentLanguageName;

  const availableLanguages = WeglotInstance.options.languages
    .filter(({ enabled }) => enabled)
    .map(({ language_to }) => language_to)
    .concat(WeglotInstance.options.language_from)
    .filter((lang) => lang !== currentLang);

  const selectList = searchContainer.querySelector(
    ".voca-js--weglot-locale-switcher-dropdown .main-footer__language"
  );
  availableLanguages.forEach((lang) => {
    const listItem = document.createElement("li");
    listItem.classList.add("text-black text-md");
    listItem.dataset.set("value", lang);

    const textItem = document.createElement("span");
    textItem.classList.add("p-2 w-full block");
    textItem.textContent = WeglotInstance.getLanguageName(lang);
    listItem.append(textItem);

    if (lang !== currentLang) {
      listItem.classList.add("hover:bg-secondary hover:text-white transition");
    }

    listItem.addEventListener("click", function (event) {
      event.preventDefault();

      const item = event.target;
      console.log("Voca Weglot clicked on", item.dataset.value);
      WeglotInstance.switchTo(item.dataset.value);
      button.textContent = WeglotInstance.getLanguageName(item.dataset.value);
    });
    selectList.appendChild(listItem);
  });

  WeglotInstance.on("languageChanged", function (lang) {
    console.log("Voca Weglot language changed to", lang);
  });
}
