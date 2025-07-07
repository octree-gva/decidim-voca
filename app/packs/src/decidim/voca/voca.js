/**
 * Public facing javascript
 */
import CustomFieldRendererOverride from "./proposal_fields/custom_field_renderer_override";
import editorBudgetField from "./proposal_fields/editor_budget_field";
import editorUploadField from "./proposal_fields/editor_upload_field";
/**
 * Wait for DecidimAwesome to be initialized, and then override the custom fields renderer.
 * Will wait for at most 640ms before raising an error.
 * @param {number} retryCount - The number of retries.
 * @returns {Promise} A promise that resolves when DecidimAwesome is initialized.
 */
const whenDecidimAwesomeInitialized = (retryCount = 0) => {
  return new Promise((resolve, reject) => {
    if (
      window.DecidimAwesome?.CustomFieldsRenderer &&
      window.DecidimAwesome?.PrivateCustomFieldsRenderer &&
      (window.DecidimAwesome?.CustomFieldsRenderer?.$element ||
        window.DecidimAwesome?.PrivateCustomFieldsRenderer?.$element)
    ) {
      resolve();
    } else {
      if (retryCount > 10) {
        return reject("decidim-voca: DecidimAwesome is not initialized");
      }
      console.warn(
        "decidim-voca: DecidimAwesome is not initialized, retrying....",
      );
      setTimeout(() => {
        whenDecidimAwesomeInitialized(retryCount + 1).then(resolve);
      }, 64);
    }
  });
};

document.addEventListener("DOMContentLoaded", () => {
  // subscribe the field in the formBuidler editor.
  // @see https://github.com/kevinchappell/formBuilder/blob/master/src/js/control/custom.js
  // @see https://formbuilder.online/docs/formBuilder/controls/#registering-the-new-types-subtypes
  editorBudgetField();
  editorUploadField();

  // wait on global DecidimAwesome to be initialized, and then override.
  whenDecidimAwesomeInitialized()
    .then(() => {
      // We monkey patch the custom fields renderer to add our own custom fields
      window.DecidimAwesome.CustomFieldsRenderer =
        new CustomFieldRendererOverride(
          window.DecidimAwesome.CustomFieldsRenderer,
        );
      window.DecidimAwesome.PrivateCustomFieldsRenderer =
        new CustomFieldRendererOverride(
          window.DecidimAwesome.PrivateCustomFieldsRenderer,
        );

      const $public = $(".proposal_custom_field:first");
      const $private = $(
        ".proposal_custom_field.proposal_custom_field--private_body:first",
      );
      let $form = null;
      if ($public.length) {
        $form =
          window.DecidimAwesome.CustomFieldsRenderer.$element.closest("form");
      }
      if ($private.length && !$form) {
        $form =
          window.DecidimAwesome.PrivateCustomFieldsRenderer.$element.closest(
            "form",
          );
      }

      if ($form) {
        $form.off("submit");
        $form.on("submit", async (evt) => {
          evt.preventDefault();
          if (evt.target.checkValidity()) {
            // save current editors
            if ($public.length) {
              await window.DecidimAwesome.CustomFieldsRenderer.storeData();
            }
            if ($private.length) {
              await window.DecidimAwesome.PrivateCustomFieldsRenderer.storeData();
            }
            evt.target.submit();
          } else {
            evt.target.reportValidity();
          }
        });
      }
    })
    .catch(() => {
      console.warn(
        "decidim-voca: DecidimAwesome is not initialized, skipping override",
      );
    });
});
