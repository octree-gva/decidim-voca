# frozen_string_literal: true

require_relative "voca/engine"
require_relative "voca/overrides/next_gen_images/decidim_viewmodel"
require_relative "voca/overrides/next_gen_images/override_for_has_one_attached"
require_relative "voca/overrides/next_gen_images/override_cell_resource_image_url"
require_relative "voca/overrides/next_gen_images/image_tag_overrides"
require_relative "voca/overrides/next_gen_images/proposal_g_cell_override"
require_relative "voca/overrides/mod_secure/user_profile_verification_override"
require_relative "voca/overrides/meetings_controller_overrides"

module Decidim
  module Voca
  end
end
