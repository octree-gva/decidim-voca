# frozen_string_literal: true

module Decidim
  module Voca
    module Overrides
      # Decidim core redirects with +id: @conversation.id+; profile routes are constrained to UUIDs
      # (+constraints(id: UUID_REGEXP)+ in {Decidim::Voca::Engine}). Use the public UUID segment so
      # Location matches {ConversationControllerOverrides} (+params[:id]+ is the UUID).
      module UserConversationsRedirectOverrides
        extend ActiveSupport::Concern

        prepended do
          def new
            @form = form(Messaging::ConversationForm).from_params(params, sender: user)

            return redirect_back(fallback_location: profile_path(user.nickname)) if @form.recipient.empty?

            @conversation = new_conversation(@form.recipient)

            return redirect_to profile_conversation_path(nickname: user.nickname, id: @conversation.uuid) if @conversation.id

            enforce_permission_to :create, :conversation, interlocutor: user, conversation: @conversation

            render :show
          end

          def create
            @form = form(Messaging::ConversationForm).from_params(params, sender: user)
            @conversation = new_conversation(@form.recipient)

            enforce_permission_to :create, :conversation, interlocutor: user, conversation: @conversation

            if @conversation.id
              flash[:alert] = I18n.t("user_conversations.create.existing_error", scope: "decidim")
              return redirect_to profile_conversation_path(nickname: user.nickname, id: @conversation.uuid)
            end

            Messaging::StartConversation.call(@form) do
              on(:ok) do |_conversation|
                flash[:notice] = I18n.t("user_conversations.create.success", scope: "decidim")
                return redirect_to profile_conversations_path(nickname: user.nickname)
              end
              on(:invalid) do
                flash[:alert] = I18n.t("user_conversations.create.error", scope: "decidim")
                render action: :show
              end
            end
          end
        end
      end
    end
  end
end
