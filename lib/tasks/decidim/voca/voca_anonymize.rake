# frozen_string_literal: true

require "faker"
require "decidim/core"
namespace :decidim do
  namespace :voca do
    desc <<~DESC
      Anonymize all the users, but the general administrators
      Name, email, nickname, password, will be changed for users and user groups.
    DESC
    task anonymize: :environment do
      raise "You are running in a production environment, task not allowed. To disable this check, set DISABLE_DATABASE_ENVIRONMENT_CHECK=1" if Rails.env.production? && ENV.fetch(
        "DISABLE_DATABASE_ENVIRONMENT_CHECK", "0"
      ) != "1"

      users = Decidim::User.where.not(admin: true)
      groups = Decidim::UserGroup.all
      users.find_each do |user|
        new_password = Devise.friendly_token.first(16)

        new_nickname = loop do
          nickname = Faker::Internet.username.gsub(/[^a-zA-Z0-9-]/, "-")[0..19]
          break nickname unless Decidim::UserBaseEntity.exists?(nickname:)
        end

        user.name = Faker::Name.name
        user.email = "#{new_nickname}@example.org"
        user.nickname = new_nickname
        user.password = new_password
        user.password_confirmation = new_password
        user.skip_confirmation!
        user.skip_reconfirmation!

        raise "Error, user not valid, #{user.errors.full_messages}" unless user.valid?

        user.save!(validate: false)
      end

      puts "Anonymized #{users.count} users"

      groups.find_each do |group|
        new_nickname = loop do
          nickname = Faker::Internet.username.gsub(/[^a-zA-Z0-9-]/, "-")[0..19]
          break nickname unless Decidim::UserBaseEntity.exists?(nickname:)
        end

        group.name = Faker::Name.name
        group.email = "#{new_nickname}@example.org"
        group.nickname = new_nickname
        group.skip_confirmation!
        group.skip_reconfirmation!
        raise "Error, group not valid, #{group.errors.full_messages}" unless group.valid?

        group.save!(validate: false)
      end

      puts "Anonymized #{groups.count} groups"
    end
  end
end
