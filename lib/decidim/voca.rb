# frozen_string_literal: true

require_relative "voca/engine"
require_relative "voca/overrides/next_gen_images/decidim_viewmodel"
require_relative "voca/overrides/next_gen_images/override_for_has_one_attached"
require_relative "voca/overrides/next_gen_images/override_cell_resource_image_url"
require_relative "voca/overrides/next_gen_images/image_tag_overrides"
require_relative "voca/overrides/next_gen_images/proposal_g_cell_override"
require_relative "voca/overrides/mod_secure/user_profile_verification_override"
require_relative "voca/overrides/geolocated_proposals/create_proposal_overrides"
require_relative "voca/overrides/geolocated_proposals/map_autocomplete_builder_overrides"
require_relative "voca/overrides/meetings_controller_overrides"
require_relative "voca/overrides/etherpad_overrides"
require_relative "voca/overrides/proposal_serializer_overrides"
require_relative "voca/overrides/user_group_form_overrides"
require_relative "voca/overrides/footer/footer_topic_cell_overrides"
require_relative "voca/overrides/footer/footer_menu_presenter"
require_relative "voca/overrides/system/system_organization_update_form"
require "good_job/engine"

module Decidim
  module Voca
    def self.configuration
      @configuration ||= Configuration.new
    end

    def self.configure
      yield configuration
    end

    def self.next_gen_images?
      configuration.enable_next_gen_images
    end

    def self.weglot?
      configuration.enable_weglot
    end

    def self.weglot_cache?
      configuration.enable_weglot_cache
    end
  end
end
