# frozen_string_literal: true

# Restore button styling removed from awesome auto_edits.scss @apply (see auto_edits.scss override).
Deface::Override.new(
  virtual_path: "decidim/decidim_awesome/admin/config/_autoedit_box_label",
  name: "voca_awesome_autoedit_delete_button_classes",
  replace: 'erb[silent]:contains("class: \"awesome-auto-delete\"")',
  text: 'class: "awesome-auto-delete button button__xs button__text-secondary"'
)
