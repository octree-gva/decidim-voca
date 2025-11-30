# frozen_string_literal: true

require "spec_helper"

module Decidim
  module Voca
    describe DeeplMiddleware do
      let(:app) { double("app") }
      let(:env) do
        {
          "PATH_INFO" => "/some/path",
          "decidim.current_organization" => organization,
          "decidim.current_participatory_space" => participatory_space,
          "decidim.current_component" => component
        }
      end
      let(:organization) { create(:organization, available_locales: I18n.available_locales) }
      let(:participatory_space) { create(:participatory_process, organization:) }
      let(:component) { create(:proposal_component, participatory_space:) }

      before do
        allow(app).to receive(:call).and_return([200, {}, ["OK"]])
        allow(Decidim::Voca).to receive(:deepl_enabled?).and_return(true)
        allow(Decidim::Voca::DeeplContext).to receive(:organization=)
        allow(Decidim::Voca::DeeplContext).to receive(:participatory_space=)
        allow(Decidim::Voca::DeeplContext).to receive(:current_component=)
        allow(Decidim::Voca::DeeplContext).to receive(:current_locale=)
        allow(Decidim::Voca::DeeplContext).to receive(:attributes).and_return({})
      end

      subject { described_class.new(app) }

      describe "#call" do
        context "when PATH_INFO starts with /rails/active_storage/" do
          let(:env) do
            { "PATH_INFO" => "/rails/active_storage/some/file" }
          end

          it "skips deepl context setting" do
            expect(Decidim::Voca::DeeplContext).not_to receive(:organization=)
            subject.call(env)
          end
        end

        context "when deepl is disabled" do
          before { allow(Decidim::Voca).to receive(:deepl_enabled?).and_return(false) }

          it "skips deepl context setting" do
            expect(Decidim::Voca::DeeplContext).not_to receive(:organization=)
            expect(Decidim::Voca::DeeplContext).not_to receive(:participatory_space=)
            expect(Decidim::Voca::DeeplContext).not_to receive(:current_component=)
            expect(Decidim::Voca::DeeplContext).not_to receive(:current_locale=)
            subject.call(env)
          end
        end

        context "when deepl is enabled" do
          it "sets the deepl context and calls the app" do
            expect(Decidim::Voca::DeeplContext).to receive(:organization=).with(organization.to_global_id.to_s)
            expect(Decidim::Voca::DeeplContext).to receive(:participatory_space=).with(participatory_space.to_global_id.to_s)
            expect(Decidim::Voca::DeeplContext).to receive(:current_component=).with(component.to_global_id.to_s)
            expect(Decidim::Voca::DeeplContext).to receive(:current_locale=).with(I18n.locale.to_s)
            expect(app).to receive(:call).with(env)

            subject.call(env)
          end
        end

        context "when an error occurs" do
          before do
            allow(Decidim::Voca::DeeplContext).to receive(:organization=).and_raise(StandardError, "Test error")
            allow(Rails.logger).to receive(:error)
          end

          it "logs the error and continues" do
            expect(Rails.logger).to receive(:error).with(/Failed to set organization context/)
            expect(Rails.logger).to receive(:error).with(/Test error/)
            expect(app).to receive(:call).with(env)

            subject.call(env)
          end
        end
      end

      describe "context setting methods" do
        before do
          allow(Decidim::Voca).to receive(:deepl_enabled?).and_return(true)
        end

        context "when organization is present" do
          it "sets organization context to a global id" do
            expect(Decidim::Voca::DeeplContext).to receive(:organization=).with(organization.to_global_id.to_s)
            subject.call(env)
          end
        end

        context "when organization is nil" do
          let(:env) do
            {
              "PATH_INFO" => "/some/path",
              "decidim.current_organization" => nil
            }
          end

          it "does not set organization context to a global id" do
            expect(Decidim::Voca::DeeplContext).not_to receive(:organization=)
            subject.call(env)
          end
        end

        context "when participatory_space is present" do
          it "sets participatory space context to a global id" do
            expect(Decidim::Voca::DeeplContext).to receive(:participatory_space=).with(participatory_space.to_global_id.to_s)
            subject.call(env)
          end
        end

        context "when participatory_space is nil" do
          let(:env) do
            {
              "PATH_INFO" => "/some/path",
              "decidim.current_organization" => organization,
              "decidim.current_participatory_space" => nil
            }
          end

          it "does not set participatory space context to a global id" do
            expect(Decidim::Voca::DeeplContext).not_to receive(:participatory_space=)
            subject.call(env)
          end
        end

        context "when component is present" do
          it "sets component context to a global id" do
            expect(Decidim::Voca::DeeplContext).to receive(:current_component=).with(component.to_global_id.to_s)
            subject.call(env)
          end
        end

        context "when component is nil" do
          let(:env) do
            {
              "PATH_INFO" => "/some/path", "decidim.current_organization" => organization,
              "decidim.current_participatory_space" => participatory_space,
              "decidim.current_component" => nil
            }
          end

          it "does not set component context to a global id" do
            expect(Decidim::Voca::DeeplContext).not_to receive(:current_component=)
            subject.call(env)
          end
        end

        it "sets locale context with the current locale string" do
          expect(Decidim::Voca::DeeplContext).to receive(:current_locale=).with(I18n.locale.to_s)
          subject.call(env)
        end
      end
    end
  end
end
