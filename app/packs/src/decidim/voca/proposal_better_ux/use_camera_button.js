import getProposalForm from "./utils/get_proposal_form";
import { initializeUploadFields } from "src/decidim/direct_uploads/upload_field";

document.addEventListener("DOMContentLoaded", () => {
  initializeUploadFields();
  const $form = getProposalForm();
  if (!$form) {
    return;
  }

  const $useCameraField = $form.find(".use_camera__input");
  if ($useCameraField.length <= 0) {
    return;
  }

  const $attachmentButton = $form.find("button[data-upload]").first();
  
  // Listen on emptyItems classList change to update the dropzone
  const observer = new MutationObserver((mutations) => {
    updateActiveUploads(modal);
  });
  observer.observe(modal.emptyItems, {
    attributes: true,
    attributeFilter: ["class"],
  });

  $useCameraField.on("change", function () {
    modal.uploadFiles(this.files);
  });
});
