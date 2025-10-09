# frozen_string_literal: true

require "spec_helper"

module Decidim
  module Voca
    describe DeeplMiddleware do
      let(:app) { double("app") }
      let(:env) { { "decidim.current_organization" => organization } }
      let(:organization) { create(:organization) }

      describe "#call" do
        it "sets the deepl context" do
          expect(Decidim::Voca::DeeplContext).to receive(:set_deepl_context).with(env)
          subject.call(env)
        end
      end

      describe "#set_deepl_context" do
        it "sets the deepl context" do
          expect(Decidim::Voca::DeeplContext).to receive(:set_deepl_context).with(env)
          subject.call(env)
          expect(Decidim::Voca::DeeplContext.organization).to eq(organization.to_global_id.to_s)
          expect(Decidim::Voca::DeeplContext.participatory_space).to eq(participatory_space.to_global_id.to_s)
          expect(Decidim::Voca::DeeplContext.current_component).to eq(component.to_global_id.to_s)
          expect(Decidim::Voca::DeeplContext.current_locale).to eq(I18n.locale)
        end
      end
    end
  end
end
