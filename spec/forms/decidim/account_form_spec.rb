# frozen_string_literal: true

require "spec_helper"
module Decidim
  RSpec.describe AccountForm do
    subject { described_class.from_model(user).with_context(current_user: user, current_organization: user.organization) }
    let(:user_password) { "decidim123456789" }  
    let(:user) { create(:user, avatar: nil, password: user_password, password_confirmation: user_password, organization: organization) }
    let(:organization) { create(:organization, available_locales: I18n.available_locales) }

    it "is valid with a name using_ letters, numbers, spaces, comas, dots, new lines and single quotes" do
      subject.name = "Maria d'Avenche da Conceição\nD. Silva, Jr."
      subject.old_password = user_password
      expect(subject).to be_valid
    end

    it "is valid with a nickname using_ letters, numbers, undescore and minus signs" do
      subject.nickname = "maria_dav"
      subject.old_password = user_password
      expect(subject).to be_valid
    end

    describe "has invalid nickname" do
      it "when a nickname with html tags is given." do
        subject.nickname = "john_<img>_doe"
        subject.old_password = user_password
        expect(subject).to be_invalid
      end

      it "when a nickname have a new line" do
        subject.nickname = "john\ndoe"
        subject.old_password = user_password
        expect(subject).to be_invalid
      end

      it "when a nickname have an dot" do
        subject.nickname = "john.doe"
        subject.old_password = user_password
        expect(subject).to be_invalid
      end

      it "when a nickname have an single quote" do
        subject.nickname = "john'doe"
        subject.old_password = user_password
        expect(subject).to be_invalid
      end
    end

    describe "has invalid name" do
      it "when a name with html tags is given." do
        subject.name = "John <img src='x'> Doe"
        subject.old_password = user_password
        expect(subject).to be_invalid
      end

      it "when a name with quotes is given." do
        subject.name = "John \"Doe\""
        subject.old_password = user_password
        expect(subject).to be_invalid
      end
    end
  end
end
