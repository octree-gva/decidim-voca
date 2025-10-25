# frozen_string_literal: true

module Decidim
  module Voca
    module Overrides
      module ConversationControllerOverrides
        extend ActiveSupport::Concern

        included do
          def conversation
            @conversation ||= Decidim::Messaging::Conversation.find_by(
              decidim_voca_conversation_uuids: { uuid: params[:id] }
            )
          end
        end
      end
    end
  end
end
