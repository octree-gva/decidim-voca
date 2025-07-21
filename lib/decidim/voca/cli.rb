# frozen_string_literal: true

require "optparse"
require "devise"
require "decidim/core"

require "tty-prompt"
require "pastel"
require "tty-table"
require "decidim/voca/cli/accounts"
require "decidim/voca/cli/main"
require "decidim/voca/cli/commands/base"
require "decidim/voca/cli/commands/config"
require "decidim/voca/cli/commands/config_get"
require "decidim/voca/cli/commands/config_set"
require "decidim/voca/cli/commands/config_list"
require "decidim/voca/cli/commands/config_delete"
require "decidim/voca/cli/commands/config_use"
require "decidim/voca/cli/commands/config_create"
