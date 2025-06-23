# frozen_string_literal: true

module Decidim
  module Voca
    module Overrides
      module ProposalGCellOverride
        extend ActiveSupport::Concern

        included do
          alias_method :decidim_voca_resource_image_path, :resource_image_path
          alias_method :decidim_voca_cache_hash, :cache_hash

          define_method :resource_image_path do
            image = model.attachments.find(&:image?)
            return nil unless image
            uploader = image.attached_uploader(:file)
            uploader.variants.map do |variant, _variant_options|
              uploader.variant_url(variant)
            end
          end

          private

          def image_hash
            @image_hash ||= Digest::MD5.hexdigest(model.photo.url) if model.photo
          end

          ##
          # Override cache hash, to include image hash and not resource_image_path (as now it's an array)
          def cache_hash
            @cache_hash ||= begin
              hash = []
              hash << I18n.locale.to_s
              hash << self.class.name.demodulize.underscore
              hash << model.cache_key_with_version
              hash << model.proposal_votes_count
              hash << model.endorsements_count
              hash << model.comments_count
              hash << Digest::MD5.hexdigest(model.component.cache_key_with_version)
              hash << image_hash if image_hash
              hash << 0 # render space
              hash << model.follows_count
              hash << Digest::MD5.hexdigest(model.authors.map(&:cache_key_with_version).to_s)
              hash << (model.must_render_translation?(model.organization) ? 1 : 0) if model.respond_to?(:must_render_translation?)
              hash << model.component.participatory_space.active_step.id if model.component.participatory_space.try(:active_step)

              hash.join(Decidim.cache_key_separator)
            end
          end
        end
      end
    end
  end
end
