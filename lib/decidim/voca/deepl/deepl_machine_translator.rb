# frozen_string_literal: true

require "deepl"
require "active_support"

module Decidim
  module Voca
    class DeeplMachineTranslator
      attr_reader :text, :source_locale, :target_locale, :resource, :field_name

      include Decidim::TranslatableAttributes

      def initialize(resource, field_name, text, target_locale, source_locale)
        @resource = resource
        @field_name = field_name
        @text = text
        @target_locale = target_locale
        @source_locale = source_locale
      end

      def translate
        return if text.blank?

        # remove base64 encoded images if they exist
        text.gsub!(%r{<img src="data:image/png;base64,.*>}, "")

        translation = segmented_translate

        Decidim::MachineTranslationSaveJob.perform_later(
          resource,
          field_name,
          target_locale,
          translation
        )
      end

      private

      def dummy_translate?
        %w(1 true enabled).include?(ENV.fetch("VOCA_DUMMY_TRANSLATE", "false"))
      end

      def segmented_translate
        # Use nokogiri parser, that will create
        # a ensure valid HTML construct,
        html = Nokogiri::HTML.fragment(text)

        html.children.each do |node|
          if node.inner_html.present?
            node.inner_html = deepl_translate(node.inner_html, html: true)
          else
            node.content = deepl_translate(node.text, html: false)
          end
        end
        html.to_s
      end

      def deepl_kwargs(html:)
        deepl_kwargs = {}

        begin
          deepl_kwargs[:enable_beta_languages] = true
        rescue StandardError => e
          Rails.logger.error("Beta Languages no supported by #{target_locale}: #{e.message}")
        end
        deepl_kwargs[:tag_handling] = "html" if html

        deepl_kwargs
      end

      def translatable?(text)
        # DeepL has a limit of 131_072 bytes per input
        # https://developers.deepl.com/docs/resources/usage-limits
        text.present? && text.bytesize < 131_000
      end

      def deepl_translate(text, html: false)
        if dummy_translate?
          context = deepl_context
          str = "DUMMY TRANSLATION [date=#{Time.current.strftime("%d/%m/%Y %H:%M:%S")},mode=#{html ? "html" : "text"},text_to_translate=\"#{text}\",context=\"#{context}\"]"
          str = "<p><strong>#{str}</strong></p>" if html
          return str.html_safe
        end

        return text unless translatable?(text)

        result = translate_with_retry(
          text,
          source_locale,
          target_locale,
          context: deepl_context,
          **deepl_kwargs(html:)
        )
        result.text
      rescue StandardError => e
        Rails.logger.error("Error translating text: #{e.message}")
        Rails.logger.error("Text: #{text}")
        Rails.logger.error("Source locale: #{source_locale}")
        Rails.logger.error("Target locale: #{target_locale}")
        Rails.logger.error("Context: #{deepl_context}")
        Rails.logger.error("Error: #{e.message}")
        Rails.logger.error("Backtrace: #{e.backtrace.join("\n")}")
        ""
      end

      def translate_with_retry(text, source_locale, target_locale, **kwargs)
        DeepL.translate(text, source_locale, target_locale, **kwargs)
      rescue RuntimeError => e
        raise unless e.message.include?("frozen") && e.message.include?("SSLContext")

        # Force a fresh connection by clearing any cached HTTP connections
        # Retry once after a brief delay to allow connection pool to reset
        sleep(1)
        DeepL.translate(text, source_locale, target_locale, **kwargs)
      end

      def target_language
        @target_language ||= DeepL.languages.find { |locale| locale.code == target_locale.to_s.upcase }
      end

      def target_language?
        target_language.present?
      end

      def deepl_context
        base = Decidim::Voca::DeeplContext.deepl_context
        "This is a text for a #{resource.class.name.demodulize.titleize} #{name_context}, field #{field_name}. #{base}"
      end

      def name_context
        return "" if field_name == "title"
        return ", named #{translated_attribute(resource.title)}" if resource.respond_to?(:title)
        return ", named #{translated_attribute(resource.name)}" if resource.respond_to?(:name)

        ""
      end
    end
  end
end
