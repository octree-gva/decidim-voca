function initializeCommentsDropdown(buttons) {
  if(buttons.length === 0) {
    return;
  }
  buttons.forEach((button) => {
    button.addEventListener("click", function (event) {
      event.preventDefault();
      event.stopPropagation();
      const target = button.getAttribute("data-target");
      const dropdown = document.getElementById(target);
      const wasHidden = dropdown.getAttribute("aria-hidden") === "true";
      console.log("WAS HIDDEN", wasHidden);
      dropdown.setAttribute("aria-hidden", !wasHidden);
      // If not hidden and click outside, click on the button again
      if (wasHidden) {
        const closeDropdown = () => {
          dropdown.setAttribute("aria-hidden", true);
          document.removeEventListener("click", closeDropdown);
        }
        document.addEventListener("click", closeDropdown);
      }
    });
  });
}

export default async function switcher() {
  const searchContainers = document.querySelectorAll(
    ".vocajs_weglot__locale_switcher"
  );
  if (!searchContainers || searchContainers.length === 0) {
    return;
  }
  const WeglotInstance = window.Weglot;
  if (!WeglotInstance) {
    return;
  }
  const buttons = []
   searchContainers.forEach((searchContainer) => {
    console.log("searchContainer", searchContainer);
    const currentLang = WeglotInstance.getCurrentLang();
    const currentLanguageName = WeglotInstance.getLanguageName(currentLang);
      const buttonContent = searchContainer.querySelector(
        ".vocajs_weglot__locale_current"
      );
    if(currentLang && currentLanguageName) {
      buttonContent.textContent = currentLanguageName;
    }
    const availableLanguages = (WeglotInstance.options.languages || [])
      .filter(({ enabled }) => enabled)
      .map(({ language_to }) => language_to)
      .concat(WeglotInstance.options.language_from)
      .filter((lang) => lang !== currentLang);

    if (availableLanguages.length > 0) {
      const selectList = searchContainer.querySelector(
        ".vocajs_weglot__locale_dropdown > ul"
      );
      const dataItemClasses = selectList.getAttribute("data-weglot-item-class");
      const dataTextItemClasses = selectList.getAttribute("data-weglot-textitem-class");
      console.log("DATA ITEM CLASSES", dataItemClasses, dataTextItemClasses);
      const itemClasses = dataItemClasses ? dataItemClasses.split(" ") : [];
      const textItemClasses = dataTextItemClasses ? dataTextItemClasses.split(" ") : [];
      availableLanguages.forEach((lang) => {
        const listItem = document.createElement("li");
        
        listItem.classList.add(...itemClasses);
        listItem.setAttribute("data-language", lang);

        const textItem = document.createElement("span");
        textItem.classList.add(...textItemClasses);
        
        textItem.textContent = WeglotInstance.getLanguageName(lang);
        listItem.append(textItem);

        listItem.addEventListener("click", function (event) {
          event.preventDefault();

          console.log("Voca Weglot clicked on", lang);
          WeglotInstance.switchTo(lang);
          buttonContent.textContent = WeglotInstance.getLanguageName(lang);
        });
        selectList.appendChild(listItem);
      });
    }
    buttons.push(searchContainer.querySelector("[data-controller='dropdown']"));
  });
  initializeCommentsDropdown(buttons);
  WeglotInstance.on("languageChanged", function (lang) {
    console.log("Voca Weglot language changed to", lang);
  });
  window.initFoundation(window.document);
}
