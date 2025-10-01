# frozen_string_literal: true

Deface::Override.new(
  virtual_path: "decidim/admin/attachments/index",
  name: "fix_attachment_file_type_index",
  replace: "erb[loud]:contains('attachment.file_type')",
  text: <<~ERB
    <%= attachment.file.blob.filename.to_s.split(".").last %>
  ERB
)
