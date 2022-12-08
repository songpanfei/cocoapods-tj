
require 'cocoapods'

module Pod
  class Installer
    class InstallationOptions
      def self.env_option(key, default = true)
        option key, ENV[key.to_s].nil? ? default : ENV[key.to_s] == 'true'
      end

      defaults.delete('warn_for_multiple_pod_sources')
      env_option :warn_for_multiple_pod_sources, false

      env_option :warn_for_unsecure_source, false

      env_option :install_with_multi_threads, true

      env_option :update_source_with_multi_processes, true
    end
  end
end
