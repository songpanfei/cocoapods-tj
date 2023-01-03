

require 'cocoapods'
require 'cocoapods-tj/config/config'

module CBin
  class Specification
    class Creator
      attr_reader :code_spec
      attr_reader :binary_source #二进制仓库地址
      attr_reader :template_spec
      attr_reader :spec

      def initialize(code_spec, binary_source, template_spec, platforms = 'ios')
        @code_spec = code_spec
        @binary_source = binary_source
        @template_spec = template_spec
        @platforms = Array(platforms)
        validate!
      end

      def validate!
        raise Pod::Informative, '源码 podspec 不能为空 .' unless code_spec
        if code_spec.subspecs.any? && template_spec.nil?
          raise Pod::Informative, "不支持自动生成存在 subspec 的二进制 podspec , 需要提供模版文件 #{code_spec.name}.binary.podspec.template ."
        end
      end

      def create
        spec = template_spec ? create_from_code_spec_and_template_spec : create_from_code_spec

        Pod::UI.message '生成二进制 podspec 内容: '
        spec.to_pretty_json.split("\n").each do |text|
          Pod::UI.message text
        end

        spec
      end

      def write_spec_file(file = filename)
        create unless spec

        File.open(file, 'w+') do |f|
          f.write(spec.to_pretty_json)
        end

        @filename = file
      end

      def clear_spec_file
        File.delete(filename) if File.exist?(filename)
      end

      def filename
        @filename ||= "#{spec.name}.podspec.json"
      end

      private

      def create_from_code_spec
        @spec = code_spec.dup

        @spec.vendored_frameworks = "#{code_spec.root.name}.framework"

        # Resources
        extnames = []
        extnames << '*.bundle' if code_spec_consumer.resource_bundles.any?
        if code_spec_consumer.resources.any?
          extnames += code_spec_consumer.resources.map { |r| File.basename(r) }
        end
        if extnames.any?
          @spec.resources = framework_contents_root().flat_map { |r| extnames.map { |e| "#{r}/#{e}" } }
        end

        # Source Location
        @spec.source = binary_source

        # Source Code
        @spec.source_files = framework_contents('Headers/*')
        @spec.public_header_files = framework_contents('Headers/*')

        # Unused for binary
        spec_hash = @spec.to_hash
        # spec_hash.delete('license')
        spec_hash.delete('resource_bundles')
        spec_hash.delete('exclude_files')
        spec_hash.delete('preserve_paths')

        spec_hash.delete('vendored_libraries')
        # spec_hash['vendored_libraries'] = binary_vendored_libraries


        platforms = spec_hash['platforms']
        selected_platforms = platforms.select { |k, _v| @platforms.include?(k) }
        spec_hash['platforms'] = selected_platforms.empty? ? platforms : selected_platforms

        @spec = Pod::Specification.from_hash(spec_hash)
        @spec
      end

      def create_from_code_spec_and_template_spec
        @spec = template_spec.dup

        @spec.version = code_spec.version
        @spec.source = binary_source

        @spec.source_files = binary_source_files
        @spec.public_header_files = binary_public_header_files
        # @spec.vendored_libraries = binary_vendored_libraries

        @spec.resources = binary_resources if @spec.attributes_hash.keys.include?("resources")



        @spec
      end

      def binary_source
        { git: @binary_source, tag:code_spec.version  }
      end

      def code_spec_consumer(_platform = :ios)
        code_spec.consumer(:ios)
      end

      def framework_contents(name)
        ["#{code_spec.root.name}.framework", "#{code_spec.root.name}.framework/Versions/A"].map { |path| "#{path}/#{name}" }
      end

      def framework_contents_root()
        ["#{code_spec.root.name}.framework", "#{code_spec.root.name}.framework/Versions/A"]
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
