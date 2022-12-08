

require 'parallel'
require 'cocoapods'

module Pod
  class Installer
    class Analyzer

      alias old_update_repositories update_repositories
      def update_repositories
        if installation_options.update_source_with_multi_processes

          Parallel.each(sources.uniq(&:url), in_processes: 4) do |source|
            if source.git?
              config.sources_manager.update(source.name, true)
            else
            end
          end
          @specs_updated = true
        else
          old_update_repositories
        end
      end


    end
  end
end
