export default function editorUploadField() {
  if (!window.fbControls) window.fbControls = new Array();
  window.fbControls.push(function (controlClass) {
    /**
     * Attach one file field.
     */
    class controlAttachFile extends controlClass {
      static get definition() {
        return {
          icon: "🏞️",
          i18n: {
            default: "Attach File",
            removeIconTitle: "Remove file",
          },
        };
      }
      configure() {}

      i18n(key) {
        return controlAttachFile.definition.i18n[key] || key;
      }
      /**
       * build a text DOM element, supporting other jquery text form-control's
       * @return DOM Element to be injected into the form.
       */
      build() {
        const { value, userData, ...attrs } = this.config;
        const currentValue = value || (userData ? userData[0] : "");
        const inputId = `${this.config.name}-input`;
        const fileControl = this.markup("input", null, {
          ...attrs,
          id: inputId,
          type: "file",
        });
        if (!currentValue) {
          this.input = fileControl;
        } else {
          const removeButton = this.markup(
            "button",
            `<svg xmlns="http://www.w3.org/2000/svg" class="formBuilder__attachFile-icon" viewBox="0 0 512 512">
              <title>${this.i18n("removeIconTitle")}</title>
              <path fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="64" d="M368 368L144 144M368 144L144 368"/>
            </svg>
          `,
            {
              class: "formBuilder__attachFile-button",
              title: this.i18n("removeIconTitle"),
              alt: "remove",
            },
          );
          const hiddenInput = this.markup("input", currentValue, {
            id: inputId,
            type: "hidden",
            value: currentValue,
            name: this.config.name,
          });
          const filename = currentValue.split("/").pop();
          const link = this.markup("a", filename, {
            href: currentValue,
            target: "_blank",
            class: "formBuilder__attachFile-preview",
          });
          const input = (this.input = this.markup(
            "div",
            [link, hiddenInput, removeButton],
            { class: "formBuilder__attachFile" },
          ));
          $(removeButton).on("click", function (evt) {
            evt.preventDefault();
            $(input).html(fileControl);
          });
        }
        return this.input;
      }

      onRender() {
        $("#" + this.config.name).html(this.config.value);
      }
    }

    // register this control for the following types & text subtypes
    controlClass.register("attachFile", controlAttachFile);
    return controlAttachFile;
  });
}
