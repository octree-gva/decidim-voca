# frozen_string_literal: true

require "spec_helper"
require "decidim/comments/test/factories"

RSpec.describe "decidim:voca:clean_machine_translations" do
  def invoke_cleanup!
    task = Rake::Task["decidim:voca:clean_machine_translations"]
    task.reenable
    task.invoke
  end

  let(:organization) do
    create(
      :organization,
      host: "#{SecureRandom.hex(8)}.example.org",
      available_locales: %w(en fr es),
      default_locale: "en",
      enable_machine_translations: true
    )
  end

  let(:participatory_process) { create(:participatory_process, :with_steps, organization:) }
  let(:step_id) { participatory_process.steps.first.id }
  let(:user) { create(:user, :admin, :confirmed, organization:) }

  let!(:component) do
    create(
      :component,
      participatory_space: participatory_process,
      name: {
        "en" => "Hello",
        "fr" => "",
        "es" => "",
        "machine_translations" => {
          "fr" => "fr - Hello",
          "es" => "es - Hello"
        }
      }
    )
  end

  before do
    allow(Decidim::Voca).to receive(:minimalistic_deepl?).and_return(true)

    Rails.application.load_tasks
  end

  it "removes stale locale keys from component translation JSON" do
    # Sysadmin changes available locales: fr,es -> fr,it
    organization.update!(available_locales: %w(en fr it))

    invoke_cleanup!

    component.reload

    expect(component.name).not_to have_key("es")
    expect(component.name.dig("machine_translations", "es")).to be_nil
    expect(component.name.dig("machine_translations", "fr")).to eq("fr - Hello")
  end

  it "removes stale locale keys from component settings (global)" do
    component.update_column(
      :settings,
      {
        "global" => {
          "dummy_global_translatable_text" => {
            "en" => "<p>Hello</p>",
            "fr" => "",
            "es" => "",
            "machine_translations" => {
              "fr" => "fr - <p>Hello</p>",
              "es" => "es - <p>Hello</p>"
            }
          }
        },
        "process_step" => {}
      }
    )

    organization.update!(available_locales: %w(en fr it))
    invoke_cleanup!

    global_value = component.reload.read_attribute(:settings).dig("global", "dummy_global_translatable_text")
    expect(global_value).not_to have_key("es")
    expect(global_value.dig("machine_translations", "es")).to be_nil
    expect(global_value.dig("machine_translations", "fr")).to eq("fr - <p>Hello</p>")
  end

  it "removes stale locale keys from component settings (process step)" do
    component.update_column(
      :settings,
      {
        "global" => {},
        "step" => {
          step_id.to_s => {
            "dummy_step_translatable_text" => {
              "en" => "<p>Hello step</p>",
              "fr" => "",
              "es" => "",
              "machine_translations" => {
                "fr" => "fr - <p>Hello step</p>",
                "es" => "es - <p>Hello step</p>"
              }
            }
          }
        }
      }
    )

    organization.update!(available_locales: %w(en fr it))
    invoke_cleanup!

    step_value = component.reload.read_attribute(:settings).dig(
      "step",
      step_id.to_s,
      "dummy_step_translatable_text"
    )
    expect(step_value).not_to have_key("es")
    expect(step_value.dig("machine_translations", "es")).to be_nil
    expect(step_value.dig("machine_translations", "fr")).to eq("fr - <p>Hello step</p>")
  end

  it "removes stale locale keys from static page title" do
    slug = "mt-static-page-#{SecureRandom.hex(4)}"

    static_page = create(
      :static_page,
      organization:,
      slug:,
      allow_public_access: false,
      weight: 0,
      title: {
        "en" => "Hello Page",
        "fr" => "",
        "es" => ""
      },
      content: {
        "en" => "<p>Hello content</p>",
        "fr" => "",
        "es" => ""
      }
    )

    static_page.update_column(
      :title,
      {
        "en" => "Hello Page",
        "fr" => "",
        "es" => "",
        "machine_translations" => {
          "fr" => "fr - Hello Page",
          "es" => "es - Hello Page"
        }
      }
    )

    organization.update!(available_locales: %w(en fr it))
    invoke_cleanup!

    value = static_page.reload.title
    expect(value).not_to have_key("es")
    expect(value.dig("machine_translations", "es")).to be_nil
    expect(value.dig("machine_translations", "fr")).to eq("fr - Hello Page")
  end

  it "removes stale locale keys from comment body" do
    component_for_proposal = create(:proposal_component, organization: participatory_process.organization)
    proposal = create(:proposal, component: component_for_proposal)

    comment = create(
      :comment,
      commentable: proposal,
      body: {
        "en" => "Hello comment",
        "fr" => "",
        "es" => "",
        "machine_translations" => {
          "fr" => "fr - Hello comment",
          "es" => "es - Hello comment"
        }
      }
    )

    organization.update!(available_locales: %w(en fr it))
    invoke_cleanup!

    value = comment.reload.body
    expect(value).not_to have_key("es")
    expect(value.dig("machine_translations", "es")).to be_nil
    expect(value.dig("machine_translations", "fr")).to eq("fr - Hello comment")
  end
end

