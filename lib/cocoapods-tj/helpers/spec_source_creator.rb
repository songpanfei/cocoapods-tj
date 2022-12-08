

require 'cocoapods'
require 'cocoapods-tj/config/config'

module CBin
  class SpecificationSource
    class Creator
      attr_reader :code_spec
      attr_reader :spec

      def initialize(code_spec, platforms = 'ios')
        @code_spec = code_spec
        @platforms = Array(platforms)
        validate!
      end

      def validate!
        raise Pod::Informative, '源码 podspec 不能为空 .' unless code_spec
      end

      def create
        # spec = nil
        if CBin::Build::Utils.is_framework(@code_spec)
          spec = create_framework_from_code_spec
        else
          spec = create_from_code_spec
        end

        spec
      end

      def write_spec_file(file = filename)
        create unless spec

        FileUtils.mkdir_p(CBin::Config::Builder.instance.binary_json_dir) unless File.exist?(CBin::Config::Builder.instance.binary_json_dir)
        FileUtils.rm_rf(file) if File.exist?(file)

        File.open(file, 'w+') do |f|
          # f.write("# MARK: converted automatically by plugin cocoapods-tj @slj \r\n")
          f.write(spec.to_pretty_json)
        end

        @filename = file
      end

      def clear_spec_file
        File.delete(filename) if File.exist?(filename)
      end

      def filename
        @filename ||= "#{CBin::Config::Builder.instance.binary_json_dir_name}/#{spec.name}.binary.podspec.json"
      end

      private

      def create_from_code_spec
        @spec = code_spec.dup

        extnames = []
        extnames << '*.bundle' if code_spec_consumer.resource_bundles.any?
        if code_spec_consumer.resources.any?
          extnames += code_spec_consumer.resources.map { |r| File.basename(r) }
        end
        if extnames.any?
          @spec.resources = framework_contents('Resources').flat_map { |r| extnames.map { |e| "#{r}/#{e}" } }
        end

        # Source Location
        @spec.source = binary_source

        # Source Code
        # @spec.source_files = framework_contents('Headers/*')
        # @spec.public_header_files = framework_contents('Headers/*')

        # Unused for binary
        spec_hash = @spec.to_hash
        # spec_hash.delete('license')
        spec_hash.delete('resource_bundles')
        spec_hash.delete('exclude_files')
        spec_hash.delete('preserve_paths')

        spec_hash.delete('subspecs')
        spec_hash.delete('default_subspecs')
        spec_hash.delete('default_subspec')
        spec_hash.delete('vendored_frameworks')
        spec_hash.delete('vendored_framework')


        spec_hash.delete('vendored_libraries')


        platforms = spec_hash['platforms']
        selected_platforms = platforms.select { |k, _v| @platforms.include?(k) }
        spec_hash['platforms'] = selected_platforms.empty? ? platforms : selected_platforms

        @spec = Pod::Specification.from_hash(spec_hash)

        @spec.prepare_command = "" if @spec.prepare_command
        @spec.version = code_spec.version
        @spec.source = binary_source
        @spec.source_files = binary_source_files
        @spec.public_header_files = binary_public_header_files
        @spec.vendored_libraries = binary_vendored_libraries
        @spec.resources = binary_resources if @spec.attributes_hash.keys.include?("resources")
        @spec.description = <<-EOF
         「       」
          #{@spec.description}
        EOF
        @spec
      end

      def create_framework_from_code_spec
        @spec = code_spec.dup

        @spec.vendored_frameworks = "#{code_spec.root.name}.framework"

        extnames = []
        extnames << '*.bundle' if code_spec_consumer.resource_bundles.any?
        if code_spec_consumer.resources.any?
          extnames += code_spec_consumer.resources.map { |r| File.basename(r) }
        end
        if extnames.any?
          @spec.resources = framework_contents('Resources').flat_map { |r| extnames.map { |e| "#{r}/#{e}" } }
        end

        @spec.source = binary_source

        spec_hash = @spec.to_hash
        # spec_hash.delete('license')
        spec_hash.delete('resource_bundles')
        spec_hash.delete('exclude_files')
        spec_hash.delete('preserve_paths')

        vendored_libraries = spec_hash.delete('vendored_libraries')
        vendored_libraries = Array(vendored_libraries).reject { |l| l.end_with?('.a') }
        if vendored_libraries.any?
          spec_hash['vendored_libraries'] = vendored_libraries
        end

        platforms = spec_hash['platforms']
        selected_platforms = platforms.select { |k, _v| @platforms.include?(k) }
        spec_hash['platforms'] = selected_platforms.empty? ? platforms : selected_platforms

        @spec = Pod::Specification.from_hash(spec_hash)
        @spec.description = <<-EOF
         「       」
          #{@spec.description}
        EOF
        @spec
      end


      def binary_source
        { http: format(CBin.config.binary_download_url, code_spec.root.name, code_spec.version), type: CBin.config.download_file_type }
      end

      def code_spec_consumer(_platform = :ios)
        code_spec.consumer(:ios)
      end

      def framework_contents(name)
        ["#{code_spec.root.name}.framework", "#{code_spec.root.name}.framework/Versions/A"].map { |path| "#{path}/#{name}" }
      end

      def binary_source_files
        { http: format(CBin.config.binary_download_url, code_spec.root.name, code_spec.version), type: CBin.config.download_file_type }
      end

      def binary_source_files
        "bin_#{code_spec.name}_#{code_spec.version}/Headers/*"
      end

      def binary_public_header_files
        "bin_#{code_spec.name}_#{code_spec.version}/Headers/*.h"
      end

      def binary_vendored_libraries
        "bin_#{code_spec.name}_#{code_spec.version}/*.a"
      end

      def binary_resources
        "bin_#{code_spec.name}_#{code_spec.version}/Resources/*"
      end

    end
  end
end

