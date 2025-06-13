# frozen_string_literal: true

require "spec_helper"
module Decidim
  RSpec.describe UserBaseEntity do
    subject { user }

    let(:user) { create(:user) }

    context "when validating user's name" do
      describe "sanitize" do
        let(:user) { build(:user) }

        it "remove new lines" do
          user.name = "John\nDoe"
          user.valid?
          expect(user.name).to eq("JohnDoe")
        end

        it "remove html tags" do
          user.name = "John<img src='x'>Doe"
          user.valid?
          expect(user.name).to eq("JohnDoe")
        end

        it "remove quotes" do
          user.name = "John \"Doe\""
          user.valid?
          expect(user.name).to eq("John Doe")
        end

        it "keeps correct characters" do
          user.name = "John Doe"
          user.valid?
          expect(user.name).to eq("John Doe")
        end

        it "keeps punctuation" do
          user.name = "John Doe, Jr."
          user.valid?
          expect(user.name).to eq("John Doe, Jr.")
        end
      end
    end

    context "when validating user's nickname" do
      describe "sanitize" do
        let(:user) { build(:user) }

        it "remove new lines" do
          user.nickname = "John\nDoe"
          user.valid?
          expect(user.nickname).to eq("johndoe")
        end

        it "downcase nickname" do
          user.nickname = "John_Doe"
          user.valid?
          expect(user.nickname).to eq("john_doe")
        end

        it "remove html tags" do
          user.nickname = "John<img src='x'>Doe"
          user.valid?
          expect(user.nickname).to eq("johndoe")
        end

        it "remove quotes" do
          user.nickname = "John \"Doe\""
          user.valid?
          expect(user.nickname).to eq("john doe")
        end

        it "keeps correct characters" do
          user.nickname = "John Doe"
          user.valid?
          expect(user.nickname).to eq("john doe")
        end

        it "keeps punctuation" do
          user.nickname = "John Doe, Jr."
          user.valid?
          expect(user.nickname).to eq("john doe, jr.")
        end
      end
    end
  end
end
