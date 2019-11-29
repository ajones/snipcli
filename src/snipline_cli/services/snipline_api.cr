require "json"

module SniplineCli::Services
  # For talking to the Snipline API.
  class SniplineApi
    include SniplineCli::Models

    # Fetches the user's Snippets.
    def fetch(&block)
      config = SniplineCli.config
      resp = Crest.get(
        "#{config.get("api.url")}/snippets",
        headers: {
          # "Accept" => "application/vnd.api+json",
          "Authorization" => "Bearer #{config.get("api.token")}",
        }
      )
      yield resp.body
    end

    def create(snippet : SnippetAttribute | SnippetSchema)
      config = SniplineCli.config
      # begin
      resp = Crest.post(
        "#{config.get("api.url")}/snippets",
        headers: {
          # "Accept" => "application/vnd.api+json",
          "Authorization" => "Bearer #{config.get("api.token")}",
        },
        form: {
          # data: {
          :name          => snippet.name.not_nil!.chomp,
          :real_command  => snippet.real_command.not_nil!.chomp,
          :documentation => snippet.documentation,
          :alias         => snippet.snippet_alias,
          :is_pinned     => snippet.is_pinned.to_s,
          # :tags => snippet.tags
          # }
        },
        logging: ENV["LOG_LEVEL"] == "DEBUG" ? true : false
      )
      SingleSnippetDataWrapper.from_json(resp.body).data
    end

    def update(snippet : SnippetSchema)
      config = SniplineCli.config
      # begin
      resp = Crest.patch(
        "#{config.get("api.url")}/snippets/#{snippet.cloud_id}",
        headers: {
          # "Accept" => "application/vnd.api+json",
          "Authorization" => "Bearer #{config.get("api.token")}",
        },
        form: {
          # data: {
          :name          => snippet.name.not_nil!.chomp,
          :real_command  => snippet.real_command.not_nil!.chomp,
          :documentation => snippet.documentation,
          :alias         => snippet.snippet_alias,
          :is_pinned     => snippet.is_pinned.to_s,
          # :tags => snippet.tags
          # }
        },
        logging: ENV["LOG_LEVEL"] == "DEBUG" ? true : false
      )
      response = SingleSnippetDataWrapper.from_json(resp.body).data
      snippet.name = response.name.not_nil!
      snippet.real_command = response.real_command.not_nil!
      snippet.documentation = response.documentation
      snippet.snippet_alias = response.snippet_alias
      snippet.is_synced = true
      snippet.is_pinned = response.is_pinned
      Repo.update(snippet)
      cloud_updated_at = Time.parse(
        response.updated_at.not_nil!,
        "%F %T",
        Time::Location::UTC
      )
      puts "cloud #{cloud_updated_at}"
      local_snippet = Repo.get_by(SniplineCli::Models::SnippetSchema, cloud_id: response.id.not_nil!)
      if local_snippet
        puts "local #{local_snippet.updated_at}"
      end

      q = Repo.raw_exec("UPDATE snippets SET updated_at=? WHERE cloud_id=?", cloud_updated_at, response.id)
      puts q.inspect
    end
  end

  class SniplineApiTest
    def fetch(&block)
      yield "{\"data\":[{\"attributes\":{\"alias\":\"git.sla\",\"documentation\":null,\"is-pinned\":false,\"name\":\"Git log pretty\",\"real-command\":\"git log --oneline --decorate --graph --all\",\"tags\":[]},\"id\":\"0f4846c0-3194-40bb-be77-8c4b136565f4\",\"type\":\"snippets\"}]}"
    end

    def create(snippet : SniplineCli::Models::Snippet)
    end

    def update(snippet : SniplineCli::Models::SnippetSchema)
    end
  end
end
