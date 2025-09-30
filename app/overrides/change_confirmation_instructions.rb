# frozen_string_literal: true

Deface::Override.new(
  virtual_path: "devise/mailer/confirmation_instructions",
  name: "confirmation_instruction_html",
  replace: "erb[loud]:contains('t(\".instruction\")')",
  text: <<~ERB
    <%= t(".instruction_html") %>
  ERB
)
