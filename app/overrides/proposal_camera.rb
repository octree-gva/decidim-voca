# frozen_string_literal: true

Deface::Override.new(
  virtual_path: "decidim/proposals/proposals/_edit_form_fields",
  name: "feat_proposal_camera_button",
  insert_after: "erb[loud]:contains('form.attachment :documents')",
  text: <<~ERB
    <label class="button button__lg button__transparent-secondary w-full use_camera">
      <%= icon "camera", class: "use_camera__icon" %>
      <span class="use_camera__label">
        <%= t("decidim.voca.proposals.take_photo") %>
      </span>
      <input type="file" name="photo_placeholder" class="use_camera__input hidden hide" accept="image/*" capture="environment">
    </label>
  ERB
)
