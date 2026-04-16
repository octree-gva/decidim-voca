# frozen_string_literal: true

require "csv"
require "decidim/core"
require "decidim/voca/sync_locales"
namespace :decidim do
  namespace :voca do
    desc <<~DESC
      Remove all translation strings that are not in default locale and
      not in machine translation. Will loop over every ActiveRecord availables.#{" "}
      This task do NOT call MachineTranslationFieldsJob ever.

      Set DRY_RUN=1 to perform no writes and print a semicolon-separated CSV to stdout:
      model;field;value (field JSON before alteration). Redirect, e.g. DRY_RUN=1 bin/rake ... > tmp/out.csv
    DESC
    task clean_machine_translations: :environment do
      dry_run = ENV["DRY_RUN"].to_s == "1"
      $stdout.puts CSV.generate_line(%w(model field value), col_sep: ";") if dry_run
      Decidim::Voca::SyncLocales::CleanMachineTranslationsRunner.new(dry_run: dry_run).call
    end
  end
end
