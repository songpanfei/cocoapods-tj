

require 'cocoapods-tj/native/specification'

module Pod
  module ExternalSources
    # Provides support for fetching a specification file from a path local to
    # the machine running the installation.
    #
    class PathSource < AbstractExternalSource
      def normalized_podspec_path(declared_path)
        extension = File.extname(declared_path)

        if extension == '.podspec' || extension == '.json'
          path_with_ext = declared_path
        else
          path_with_ext = Specification::VALID_EXTNAME
                          .map { |extname| "#{declared_path}/#{name}#{extname}" }
                          .find { |file| File.exist?(file) } || "#{declared_path}/#{name}.podspec"
        end


        podfile_dir = File.dirname(podfile_path || '')

        File.expand_path(path_with_ext, podfile_dir)
      end
    end
  end
end
