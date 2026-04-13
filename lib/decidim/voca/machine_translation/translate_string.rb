# frozen_string_literal: true

require "nokogiri"

module Decidim
  module Voca
    module MachineTranslation
      # Shared string translation for MT paths that cannot use +MachineTranslationSaveJob+ (no DB column).
      module TranslateString
        class << self
          def call(text:, source_locale:, target_locale:, html: false, context: nil)
            klass = Decidim.machine_translation_service_klass
            return nil if klass.blank?
            return "" if text.blank?

            work = text.dup
            work.gsub!(%r{<img src="data:image/png;base64,.*>}, "")

            return dummy_dev_translation(work, target_locale) if klass == Decidim::Dev::DummyTranslator

            return dummy_deepl_style_translation(work, target_locale, html) if dummy_translate?

            return nil unless translatable?(work)
            return nil unless deepl_service?(klass)

            segmented_translate(work, source_locale.to_s, target_locale.to_s, html:, context:)
          end

          def dummy_translate?
            %w(1 true enabled).include?(ENV.fetch("VOCA_DUMMY_TRANSLATE", "false"))
          end

          def deepl_service?(klass)
            klass.to_s == "Decidim::Voca::DeeplMachineTranslator" && Decidim::Voca.deepl_enabled?
          end

          def translatable?(text)
            text.present? && text.bytesize < 131_000
          end

          def mutex
            @mutex ||= Mutex.new
          end

          def dummy_dev_translation(work, target_locale)
            "#{target_locale} - #{work}"
          end

          def dummy_deepl_style_translation(work, _target_locale, html)
            ctx = Decidim::Voca::DeeplContext.deepl_context
            str = "DUMMY TRANSLATION [date=#{Time.current.strftime("%d/%m/%Y %H:%M:%S")},mode=#{html ? "html" : "text"},text_to_translate=\"#{work}\",context=\"#{ctx}\"]"
            str = "<p><strong>#{str}</strong></p>" if html
            str.html_safe
          end

          def segmented_translate(text, source_locale, target_locale, html:, context:)
            return deepl_translate_segment(text, source_locale, target_locale, html: false, context:) unless html

            fragment = Nokogiri::HTML.fragment(text)
            fragment.children.each do |node|
              if node.inner_html.present?
                node.inner_html = deepl_translate_segment(node.inner_html, source_locale, target_locale, html: true, context:)
              else
                node.content = deepl_translate_segment(node.content, source_locale, target_locale, html: false, context:)
              end
            end
            fragment.to_s
          end

          def deepl_translate_segment(text, source_locale, target_locale, html:, context:)
            return text unless translatable?(text)
            return dummy_deepl_style_translation(text, target_locale, html) if dummy_translate?

            return text unless defined?(DeepL) && Decidim::Voca.deepl_enabled?

            mutex.synchronize do
              result = DeepL.translate(
                text,
                source_locale,
                target_locale,
                context: full_context(context),
                **deepl_kwargs(target_locale, html:)
              )
              result.text
            rescue StandardError => e
              Rails.logger.error("Voca TranslateString: #{e.message}")
              raise e
            end
          end

          def full_context(context)
            base = Decidim::Voca::DeeplContext.deepl_context
            [context, base].compact.join(" ")
          end

          def deepl_kwargs(target_locale, html:)
            kwargs = {}
            kwargs[:formality] = "prefer_more" if supports_formality?(target_locale)
            kwargs[:tag_handling] = "html" if html
            kwargs
          end

          def supports_formality?(target_locale)
            lang = DeepL.languages.find { |locale| locale.code == target_locale.to_s.upcase }
            lang&.supports_formality?
          rescue DeepL::Exceptions::NotSupported, NoMethodError
            false
          end
        end
      end
    end
  end
end
