require "db"
require "sqlite3"
require "json"
require "crecto"
require "../helpers/*"

module SniplineCli::Services
  # Keeps the database structure up to date
  class Migrator
    def self.run
      config = SniplineCli.config
      File.write(expand_path(config.get("general.db")), "", mode: "w") unless File.exists?(expand_path(config.get("general.db")))
      DB.open "sqlite3:#{expand_path(config.get("general.db"))}" do |db|
        db.exec "create table if not exists snippets (
					local_id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
					cloud_id TEXT NULL,
					name TEXT NOT NULL,
					snippet_alias TEXT NULL UNIQUE,
					documentation TEXT NULL,
					real_command TEXT NOT NULL,
					tags TEXT NULL,
					is_synced BOOLEAN DEFAULT 0,
					is_pinned BOOLEAN DEFAULT 0,
					inserted_at DATETIME DEFAULT CURRENT_TIMESTAMP,
					updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
					)"
        db.exec "create table if not exists schema (version)"
        begin
          db.query_one "select version from schema", &.read(Int)
        rescue ex : DB::Error
          db.exec "insert into schema (version) values (?)", 1
        end

        # Import 0.2.0 snippets from JSON file
        if File.exists?(expand_path(config.get("general.file")))
          # Get the snippets
          json = File.read(expand_path(config.get("general.file")))
          # import into DB
          p "Importing JSON snippets into SQLite Database"
          Array(SnippetParser).from_json(json).each do |snippet_json|
            p "#{snippet_json.inspect}"
            snippet = Snippet.new
            snippet.cloud_id = snippet_json.id
            snippet.name = snippet_json.name
            snippet.real_command = snippet_json.real_command
            snippet.documentation = snippet_json.documentation
            snippet.tags = (snippet_json.tags) ? snippet_json.tags.not_nil!.join(",") : nil
            snippet.snippet_alias = snippet_json.snippet_alias
            snippet.is_pinned = snippet_json.is_pinned
            snippet.is_synced = false
            changeset = Snippet.changeset(snippet)
            unless changeset.valid?
              p "Could not import snippet #{snippet.name} from the old 0.2.0 JSON file to the new 0.3.0+ SQLite database.".colorize(:red)
              p "Reasons given:".colorize(:red)
              changeset.errors.each do |error|
                puts "#{error.inspect}".colorize(:red)
              end
              p ""
              abort("Please fix this error and re-run the init command")
            end
            if changeset.valid?
              Repo.insert(changeset)
            end
          end
          File.delete(expand_path(config.get("general.file")))
        end
      end
    end
  end
end
