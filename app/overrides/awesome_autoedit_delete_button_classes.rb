# frozen_string_literal: true

# Restore button styling removed from awesome auto_edits.scss @apply (see auto_edits.scss override).
# replace swaps the whole erb node, so text is the full opening tag.
Deface::Override.new(
  virtual_path: "decidim/decidim_awesome/admin/config/_autoedit_box_label",
  name: "voca_awesome_autoedit_delete_button_classes",
  replace: %q{erb[loud]:contains('class: "awesome-auto-delete"')},
  # var stays literal until the partial renders. Double quotes would interpolate it when this file loads.
  # rubocop:disable Lint/InterpolationCheck, Style/StringLiterals
  text: '<%= link_to delete_path, method: :delete, ' \
        'class: "awesome-auto-delete button button__xs button__text-secondary", ' \
        'title: t("remove", scope: "decidim.decidim_awesome.admin.config.form_#{var}"), ' \
        'data: { confirm: t("sure_to_remove", scope: "decidim.decidim_awesome.admin.config.form_#{var}") } do %>',
  # rubocop:enable Lint/InterpolationCheck, Style/StringLiterals
  original: "1cf9f4e9947f459ef8951710eef6fae681187b1d"
)
