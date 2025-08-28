export default async function switcher() {
  const searchContainer = document.querySelector(
    ".main-footer__language-container.voca-js--weglot-locale-switcher"
  );
  if (!searchContainer || searchContainer.length === 0) {
    return;
  }

  if (!Weglot) {
    return;
  }

  //Create array of options to be added
  const availableLanguages = Weglot.options.languages
    .map(function ({ language_to }) {
      return language_to;
    })
    .concat(Weglot.options.language_from);

  const selectList = searchContainer.querySelector(
    ".voca-js--weglot-locale-switcher-dropdown .main-footer__language"
  );

  const currentLang = Weglot.getCurrentLang();
  availableLanguages.forEach((lang) => {
    const listItem = document.createElement("li");
    listItem.classList.add("text-black text-md");
    listItem.dataset.set("value", lang);

    const textItem = document.createElement("span");
    textItem.classList.add("p-2 w-full block");
    textItem.textContent = Weglot.getLanguageName(lang);
    listItem.append(textItem);

    if (lang !== currentLang) {
      listItem.classList.add("hover:bg-secondary hover:text-white transition");
    }
    listItem.addEventListener("click", function (event) {
      event.preventDefault();

      const item = event.target;
      console.log("Voca Weglot clicked on", item.dataset.value);
      Weglot.switchTo(item.dataset.value);
    });
    selectList.appendChild(listItem);
  });

  Weglot.on("languageChanged", function (lang) {
    console.log("Voca Weglot language changed to", lang);
  });
}
