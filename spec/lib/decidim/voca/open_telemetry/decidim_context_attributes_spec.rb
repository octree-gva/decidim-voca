# frozen_string_literal: true

require "spec_helper"

module Decidim
  module Voca
    module OpenTelemetry
      describe DecidimContextAttributes do
        let(:test_class) { Class.new { include DecidimContextAttributes } }
        let(:subject) { test_class.new }

        describe "#set_attribute" do
          it "sets key on a Hash target" do
            target = {}
            subject.send(:set_attribute, target, "key", "value")
            expect(target["key"]).to eq("value")
          end

          it "calls set_attribute on target when it responds to set_attribute" do
            target = double("span")
            allow(target).to receive(:set_attribute)
            subject.send(:set_attribute, target, "key", "value")
            expect(target).to have_received(:set_attribute).with("key", "value")
          end

          it "raises ArgumentError when target is not Hash and does not respond to set_attribute" do
            target = Object.new
            expect { subject.send(:set_attribute, target, "key", "value") }.to raise_error(ArgumentError, /set_attribute or be a Hash/)
          end
        end

        describe "#set_organization_attributes" do
          it "does nothing when env has no decidim.current_organization" do
            target = {}
            subject.set_organization_attributes({}, target)
            expect(target).to be_empty
          end

          it "sets organization id and slug when organization is present" do
            org = double("org", id: 1, slug: "my-org", host: nil)
            env = { "decidim.current_organization" => org }
            target = {}
            subject.set_organization_attributes(env, target)
            expect(target["decidim.organization.id"]).to eq("1")
            expect(target["decidim.organization.slug"]).to eq("my-org")
          end
        end
      end
    end
  end
end
