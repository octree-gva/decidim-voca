# frozen_string_literal: true

module Decidim
  module Voca
    module Overrides
      # Injected into Decidim::Messaging::Conversation model to generate a UUID for the conversation
      module ConversationUuid
        extend ActiveSupport::Concern

        included do
          has_one :conversation_uuid,
                  class_name: "Decidim::Voca::ConversationUuid",
                  foreign_key: :decidim_conversation_id,
                  autosave: true,
                  inverse_of: :conversation
          default_scope { joins(:conversation_uuid).order(updated_at: :desc) }

          after_create :generate_uuid
          delegate :uuid, to: :conversation_uuid, allow_nil: true

          def to_param
            uuid
          end

          private

          def generate_uuid
            self.conversation_uuid = Decidim::Voca::ConversationUuid.create(conversation: self)
          end
        end
      end
    end
  end
end
