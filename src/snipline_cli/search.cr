require "json"
require "colorize"

module SniplineCli
    class Command < Admiral::Command
		class Search < Admiral::Command
            define_help description: "For searching your snippets"
            define_argument search_term : String,
                description: "The term to search for",
                default: nil,
                required: false
            define_flag limit : UInt32, default: 5_u32, long: limit

			def run
				puts "Searching..."
                Crest.get(
                    "http://localhost:4001/api/snippets",
                    headers: {
                        # "Accept" => "application/vnd.api+json",
                        "Authorization" => "Bearer #{ENV["TOKEN"]}",
                    }) do |resp|
                        # puts response.body.inspect
                        snippets = SnippetDataWrapper.from_json resp.body
                        case arguments.search_term
                        when String
                            snippets.data.select { |i| 
                                lowered_search_term = arguments.search_term.as(String).downcase
                                i.name.downcase.includes?(lowered_search_term) || i.real_command.downcase.includes?(lowered_search_term) || i.tags.includes?(lowered_search_term)
                            }.sort { |snippet_a, snippet_b| 
                                if snippet_a.is_pinned && snippet_b.is_pinned
                                    snippet_a.name <=> snippet_b.name
                                elsif snippet_a.is_pinned
                                    -1
                                elsif snippet_b.is_pinned
                                    1
                                else
                                    snippet_a.name <=> snippet_b.name
                                end
                            }.first(flags.limit).each_with_index { |snippet, index|
                                puts "##{index + 1} #{snippet.name.colorize(:green)} #{snippet.is_pinned ? "⭐️" : ""}\n#{snippet.real_command}\n[#{snippet.tags.join(",")}]"
                            }
                        else
                            snippets.data.first(flags.limit).each_with_index do |snippet, index|
                                puts "##{index + 1} #{snippet.name.colorize(:green)} #{snippet.is_pinned ? "⭐️" : ""}\n#{snippet.real_command}\n[#{snippet.tags.join(",")}]"
                            end
                        end
                        # snippets.each do |snippet|
                        #     puts "#{snippet.name}"
                        # end
                        # body = JSON.parse(resp.body)
                        # data = body["data"]
                        # snippets = Snippet.from_json(data)
                        # puts data.inspect
                        # parsed_data = data["data"].as(Array)
                        # parsed_data.each do |d|
                        # end
                        # case parsed_data
                        # when Array(JSON::Any)
                        #     puts "woot"
                        # else
                        #     puts "nope"
                        # end
                        # parsed_data.each do |snippet|
                        #     puts snippet["name"]
                        # end
                end
			end
		end
		register_sub_command :search, Search
    end
end