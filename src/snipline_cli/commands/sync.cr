require "json"
require "colorize"
require "file_utils"
require "toml"

module SniplineCli
  class Command < Admiral::Command
    # The command to sync your snippets with your active Snipline account.
    #
    # ```bash
    # snipcli sync
    # ```
    class Sync < Admiral::Command
      define_help description: "For syncing snippets from Snipline"

      property snipline_api : (SniplineCli::Services::SniplineApi | SniplineCli::Services::SniplineApiTest) = SniplineCli::Services::SniplineApi.new
      property file : (SniplineCli::Services::StoreSnippets) = SniplineCli::Services::StoreSnippets.new

      def run
				puts "Migrating Database..."
				SniplineCli::Services::Migrator.run
        puts "Syncing snippets..."
        config = SniplineCli.config
				if config.get("api.token") == ""
					abort("#{"No API token. Run".colorize(:red)} #{"snipcli login".colorize(:red).mode(:bold)} #{"to login".colorize(:red)}")
				end

				sync_unsynced_snippets
        @snipline_api.fetch do |body|
          cloud_snippets = Models::SnippetDataWrapper.from_json(body).data
					save_new_snipline_cloud_snippets(cloud_snippets)
					delete_orphan_snippets(cloud_snippets)
					update_locally_out_of_date_snippets(cloud_snippets)
					update_cloud_out_of_date_snippets(cloud_snippets)
				end
      end

			def update_locally_out_of_date_snippets(cloud_snippets)
				# TODO: this method is for local snippets whose updated_at is behind the cloud
				puts "local"
				cloud_snippets.each { |cs|
					local_snippet = Repo.get_by(SniplineCli::Models::SnippetSchema, cloud_id: cs.id.not_nil!)
					puts "#{local_snippet.inspect}"
					if local_snippet
						# cloud_updated_at = Time::Format.new(cs.not_nil!.updated_at.not_nil!).parse(cs.not_nil!.updated_at.not_nil!, Time::Location::UTC)
						cloud_updated_at = Time.parse(
							cs.not_nil!.updated_at.not_nil!,
							"%F %T",
							Time::Location::UTC
						)
						# 	cloud_updated_at.year,
						# 	cloud_updated_at.month,
						# 	cloud_updated_at.day,
						# 	cloud_updated_at.hour,
						# 	cloud_updated_at.minute,
						# 	cloud_updated_at.second
						# )
						local_updated_at = local_snippet.not_nil!.updated_at.not_nil!
						puts "ls #{local_updated_at.inspect} #{cloud_updated_at.inspect}"
						if (local_updated_at - cloud_updated_at).minutes > 1
							puts "Updating local snippet from cloud"
							local_snippet.name = cs.not_nil!.name.not_nil!
							local_snippet.real_command = cs.not_nil!.real_command.not_nil!
							local_snippet.documentation = cs.not_nil!.documentation
							local_snippet.snippet_alias = cs.not_nil!.snippet_alias
							local_snippet.snippet_alias = cs.not_nil!.snippet_alias
							local_snippet.is_synced = true
							local_snippet.is_pinned = cs.not_nil!.is_pinned
							Repo.update(local_snippet)
						elsif (local_updated_at - cloud_updated_at).minutes < 1
							puts "Sending local update to snipline"
							# TODO
						else
							# DO NOTHING
						end
						# if local_snippet.updated_at < cs.not_nil!.updated_at
						# end
					end
				}
			end

			def update_cloud_out_of_date_snippets(cloud_snippets)
				# TODO: this method is for cloud snippets whose updated_at is behind the local version
			end

			def delete_orphan_snippets(cloud_snippets)
				# if snippet cloud_id exists locally but not in cloud
				puts "Cleaning up snippets that are no longer in Snipline Cloud..."
				local_snippets = SniplineCli::Services::LoadSnippets.run.select { |ls| !ls.cloud_id.nil? }
				orphans = [] of SniplineCli::Models::SnippetSchema
				cloud_snippet_ids = cloud_snippets.map { |s| s.not_nil!.id }
				local_snippets.each do |ls|
					orphans << ls unless cloud_snippet_exists?(ls, cloud_snippet_ids)
				end
				orphans.each do |ls|
					# delete snippets
					puts "Deleting #{ls.name}".colorize(:green)
					Repo.delete(ls)
				end
			end

			def cloud_snippet_exists?(local_snippet, cloud_snippet_ids)
				cloud_snippet_ids.includes?(local_snippet.cloud_id.not_nil!)
			end


			def save_new_snipline_cloud_snippets(cloud_snippets)
				# Save the response JSON into a file without the data wrapper
				local_snippets = SniplineCli::Services::LoadSnippets.run
				begin
					# Only snippets that are in the cloud but not stored locally
					difference = [] of SniplineCli::Models::Snippet
					local_snippet_cloud_ids = local_snippets.select{ |s| !s.cloud_id.nil? }.map { |s| s.cloud_id.not_nil! }
					cloud_snippets.each do |cs|
						difference << cs unless local_snippet_exists?(cs, local_snippet_cloud_ids)
					end
					difference.each do |s|
						puts "Storing #{s.attributes.name} from Snipline".colorize(:green)
						snippet = SniplineCli::Models::SnippetSchema.new
						snippet.name = s.name
						snippet.cloud_id = s.id
						snippet.real_command = s.real_command
						snippet.documentation = s.documentation
						snippet.tags = (s.tags.nil?) ? nil : s.tags.not_nil!.join(",")
						snippet.snippet_alias = s.snippet_alias
						snippet.is_pinned = s.is_pinned
						snippet.is_synced = true
						changeset = SniplineCli::Models::SnippetSchema.changeset(snippet)
						result = Repo.insert(changeset)
						# local_snippets << s
					end
					# @file.store(local_snippets.to_json) unless difference.size == 0
				rescue ex
					puts ex.message.colorize(:red)
				end
			end

			def local_snippet_exists?(cs, local_snippet_ids)
				unless cs.id.nil?
					return local_snippet_ids.includes?(cs.id.not_nil!)
				end
				return false
			end

			def sync_unsynced_snippets
				local_snippets = SniplineCli::Services::LoadSnippets.run
				local_snippets.select { |s| s.cloud_id.nil? }.each do |snippet|
					puts "Attempting to store #{snippet.name.colorize.mode(:bold)} in Snipline..."
					begin
						cloud_snippet = SniplineCli::Services::SyncSnippetToSnipline.handle(snippet)
						update_local_snippet_id(cloud_snippet, snippet)
						puts "Success!".colorize(:green)
					rescue ex : Crest::UnprocessableEntity
						resp = SniplineCli::Models::SnippetErrorResponse.from_json(ex.response.not_nil!.body)
						puts "Failed: #{resp.errors.first.source["pointer"].gsub("/data/attributes/", "")} #{resp.errors.first.detail}".colorize(:red)
					rescue ex
						abort ex.message
					end
				end
			end

			def update_local_snippet_id(cloud_snippet, local_snippet)
				local_snippet.cloud_id = cloud_snippet.id
				local_snippet.is_synced = true
				changeset = Repo.update(local_snippet)
			end
    end

    register_sub_command :sync, Sync
  end
end
