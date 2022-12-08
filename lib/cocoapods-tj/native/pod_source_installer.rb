

require 'cocoapods-tj/native/installation_options'

module Pod
  class Installer
    class PodSourceInstaller
      attr_accessor :installation_options

      alias old_verify_source_is_secure verify_source_is_secure
      def verify_source_is_secure(root_spec)
        if installation_options.warn_for_unsecure_source?
          old_verify_source_is_secure(root_spec)
        end
      end
    end
  end
end
