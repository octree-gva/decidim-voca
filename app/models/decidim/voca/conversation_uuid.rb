# frozen_string_literal: true

module Decidim
  module Voca
    class ConversationUuid < ApplicationRecord
      self.table_name = "decidim_voca_conversation_uuids"

      before_create :generate_uuid
      belongs_to :conversation, foreign_key: :decidim_conversation_id, class_name: "Decidim::Messaging::Conversation"

      private

      def generate_uuid
        self.uuid = SecureRandom.uuid
      end
    end
  end
end
