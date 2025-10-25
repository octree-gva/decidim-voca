# frozen_string_literal: true

require "spec_helper"

module Decidim
  describe PushNotificationMessage do
    subject { push_notification_message }

    let!(:organization) { create(:organization, favicon:) }
    let(:conversation) { create(:conversation) }
    let(:recipient) { build(:user, organization:) }
    let(:favicon) { nil }
    let(:push_notification_message) { build(:push_notification_message, recipient:, conversation:) }

    describe "#url" do
      it "returns the conversation url" do
        expect(subject.url).to eq("/conversations/#{conversation.uuid}")
      end
    end
  end
end
