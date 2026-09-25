# frozen_string_literal: true

require "decidim/voca/sync_locales"

namespace :decidim do
  namespace :voca do
    desc <<~DESC.chomp
      Fill blank Decidim::TermCustomizer::Translation locale rows from the customized
      default-locale value via DeepL (no search rebuild). Requires term_customizer gem
      and minimalistic DeepL.
    DESC
    task sync_term_customizer_locales: :environment do
      unless Decidim::Voca::SyncLocales::TermCustomizerSync.available?
        raise(
          StandardError,
          "Decidim::TermCustomizer is not available. " \
          "Install decidim-term_customizer and run its migrations."
        )
      end
      unless Decidim::Voca.minimalistic_deepl?
        raise(
          StandardError,
          "Decidim::Voca.minimalistic_deepl? must be true to run sync_term_customizer_locales"
        )
      end

      Decidim::Voca::SyncLocales::TermCustomizerSync.new.call(print_summary: true)
    end
  end
end
