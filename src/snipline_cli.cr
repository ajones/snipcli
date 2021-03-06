require "admiral"
require "crest"
require "toml"
require "json"
require "ncurses"
require "sqlite3"
require "crecto"
require "log"

require "./snipline_cli/config"
require "./snipline_cli/helpers/*"
require "./snipline_cli/exceptions/*"
require "./snipline_cli/parsers/*"
require "./snipline_cli/models/*"
require "./snipline_cli/ncurses_windows/*"
require "./snipline_cli/services/*"
require "./snipline_cli/commands/*"

include SniplineCli::Services

Log.setup_from_env

module Repo
  extend Crecto::Repo

  config do |conf|
    conf.adapter = Crecto::Adapters::SQLite3
    conf.database = SniplineCli::Helpers.expand_path(SniplineCli.config.get("general.db"))
  end
end

module SniplineCli
  VERSION = "0.5.0"

  def self.config
    Config.config
  end

  def self.config_file
    ENV.has_key?("CONFIG_FILE") ? ENV["CONFIG_FILE"] : "~/.config/snipline/config.toml"
  end

  # The base Command Class that inherits from [Admiral](https://github.com/jwaldrip/admiral.cr)
  #
  # This command is not used by itself
  # It is here to set up usage for other commands.
  class Command < Admiral::Command
    define_version SniplineCli::VERSION
    define_help description: "Snipline CLI"

    def run
    end
  end
end

SniplineCli::Command.run
