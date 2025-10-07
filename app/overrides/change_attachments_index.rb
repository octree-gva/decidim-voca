# frozen_string_literal: true

Deface::Override.new(
  virtual_path: "decidim/admin/attachments/index",
  name: "fix_attachment_file_type_index",
  replace: "erb[loud]:contains('attachment.file_type')",
  text: <<~ERB
    <%= attachment.file? ? attachment.file.blob.filename.extension_without_delimiter : "link" %>
  ERB
)
