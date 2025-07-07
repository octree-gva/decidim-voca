import editorBudgetField from "../proposal_fields/editor_budget_field";
import editorUploadField from "../proposal_fields/editor_upload_field";

document.addEventListener("DOMContentLoaded", () => {
  editorBudgetField();
  // If current page ends with proposal_private_custom_fields, load upload field module
  editorUploadField();
  if(window.location.pathname.endsWith("proposal_private_custom_fields")) {
  }
});