

require 'cocoapods-tj/native/sources_manager.rb'
require 'cocoapods-tj/helpers/spec_creator'

module CBin
  module SpecFilesHelper
    def spec_files
      @spec_files ||= Pathname.glob('*.podspec{,.json}')
    end

    def binary_spec_files
      @binary_spec_files ||= Pathname.glob('*.binary.podspec{,.json}')
    end

    def binary_template_spec_files
      @binary_spec_template_files ||= Pathname.glob('*.template.podspec{,.json}')
    end

    def binary_template_spec_file
      @binary_spec_template_file ||= binary_template_spec_files.first
    end

    def code_spec_files
      @code_spec_files ||= spec_files - binary_spec_files - binary_template_spec_files
    end

    def code_spec
      if code_spec_files.first
        Pod::Specification.from_file(code_spec_files.first)
     end
    end

    def binary_spec
      if binary_spec_files.first
        Pod::Specification.from_file(binary_spec_files.first)
     end
    end

    def binary_template_spec
      if binary_template_spec_file
        Pod::Specification.from_file(binary_template_spec_file)
     end
    end

    def find_spec_file(podspec)
      path = Pathname(podspec)
      raise Pod::Informative, "无法找到 #{podspec}" unless path.exist?

      path
    end

    def create_binary_spec_file(code_spec,binary_source,template_spec)


      unless code_spec
        raise Pod::Informative, '没有二进制 podspec 的情况下，必须要提供源码 podspec.'
     end
      if code_spec.subspecs.any? && template_spec.nil?
        raise Pod::Informative, '拥有 subspec 的组件，在生成二进制 podspec 时，必须要提供模版 podspec.'
     end

      @spec_creator = CBin::Specification::Creator.new(code_spec, binary_source , template_spec)
      @spec_creator.create
      @spec_creator.write_spec_file
      @spec_creator.filename
    end

    def clear_binary_spec_file_if_needed
      @spec_creator&.clear_spec_file
    end
  end
end
