module SniplineCli
  module Services
    # Creates a config directory for storing configuration files for SnipCLI.
    class CreateConfigDirectory
      def self.run(file)
        directory_name = File.expand_path(File.dirname(file))
        unless File.directory?(directory_name)
          SniplineCli.log.debug("Making config directory #{directory_name}")
          Dir.mkdir(directory_name)
        end
      end
    end
  end
end
