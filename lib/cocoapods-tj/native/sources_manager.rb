

require 'cocoapods'
require 'cocoapods-tj/config/config'

module Pod
  class Source
    class Manager
      def code_source
        nsme = "#{CBin.config.code_repo_url}"
        source_with_name_or_url(CBin.config.code_repo_url)
      end
      def binary_source
        source_with_name_or_url(CBin.config.binary_repo_url)
      end
    end
  end
end
