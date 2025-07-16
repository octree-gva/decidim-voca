import editorBudgetField from "../proposal_custom_fields/editor_budget_field";
import editorUploadField from "../proposal_custom_fields/editor_upload_field";

document.addEventListener("DOMContentLoaded", () => {
  editorBudgetField();
  const urlParams = new URLSearchParams(window.location.search);
  const forceAwesomeAttach = urlParams.has('force_awesome_attach_file');

  if (forceAwesomeAttach || window.location.pathname.endsWith("proposal_private_custom_fields")) {
    editorUploadField();
  }
});
