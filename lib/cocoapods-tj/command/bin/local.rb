
require 'cocoapods-tj/native/podfile'
require 'cocoapods/command/gen'
require 'cocoapods/generate'
require 'cocoapods-tj/helpers/local/local_framework_builder'
require 'cocoapods-tj/helpers/local/local_library_builder'
require 'cocoapods-tj/helpers/local/local_build_helper'
require 'cocoapods-tj/helpers/spec_source_creator'
require 'cocoapods-tj/config/config_builder'

module Pod
  class Command
    class Bin < Command
      class Local < Bin
        self.summary = ''
        self.description = <<-DESC

        DESC

        def self.options
          [
            ['--no-clean', '保留构建中间产物'],
            ['--framework-output', '输出framework文件'],
            ['--no-zip', '不压缩静态 framework 为 zip'],
            ['--make-binary-specs', '需要制作spec集合'],
            ['--env', "该组件上传的环境 %w[dev debug_iphoneos release_iphoneos]"]
          ].concat(Pod::Command::Gen.options).concat(super).uniq
        end

        def initialize(argv)
          @env = argv.option('env') || 'dev'
          CBin.config.set_configuration_env(@env)


          @make_binary_specs = argv.option('make-binary-specs') || []
          @framework_output = argv.flag?('framework-output', false)
          @clean = argv.flag?('no-clean', true)
          @zip = argv.flag?('zip', true)
          @sources = argv.option('sources') || []
          @platform = Platform.new(:ios)

          @target_name = CBin::Config::Builder.instance.target_name
          @local_build_dir_name = CBin::Config::Builder.instance.xcode_build_name
          @local_build_dir = CBin::Config::Builder.instance.xcode_build_dir

          @framework_path
          super
        end

        def run


          sources_spec = []
          Dir.chdir(CBin::Config::Builder.instance.local_psec_dir) do
            spec_files = Dir.glob(%w[*.json *.podspec])
            spec_files.each do |file|
              spec = Pod::Specification.from_file(file)
              sources_spec << spec
            end
          end

          build(sources_spec)
        end

        def build(make_binary_specs)
          sources_sepc = []
          make_binary_specs.uniq.each do |spec|
            next if spec.name.include?('/')
            next if spec.name == @target_name
            next if CBin::Config::Builder.instance.white_pod_list.include?(spec.name)
            if spec.source[:git] && spec.source[:git]
              spec_git = spec.source[:git]
              spec_git_res = false
              CBin::Config::Builder.instance.ignore_git_list.each do |ignore_git|
                spec_git_res = spec_git.include?(ignore_git)
                break if spec_git_res
              end
              next if spec_git_res
            end
            UI.warn "#{spec.name}.podspec 带有 vendored_frameworks 字段，请检查是否有效！！！" if spec.attributes_hash['vendored_frameworks']
            next if spec.attributes_hash['vendored_frameworks'] && @target_name != spec.name #过滤带有vendored_frameworks的
            next if (spec.attributes_hash['ios'] && spec.attributes_hash['ios']['vendored_frameworks'])  #过滤带有vendored_frameworks的

            next unless library_exist(spec)

            sources_sepc << spec
          end

          fail_build_specs = []
          sources_sepc.uniq.each do |spec|
            begin
              builder = CBin::LocalBuild::Helper.new(spec,
                                                     @platform,
                                                     @framework_output,
                                                     @zip,
                                                     @clean,
                                                     @target_name,
                                                     @local_build_dir_name,
                                                     @local_build_dir)
              builder.build
              CBin::Upload::Helper.new(spec, @code_dependencies, @sources).upload
            rescue StandardError
              fail_build_specs << spec
            end
          end

          if fail_build_specs.any?
            fail_build_specs.uniq.each do |spec|
              UI.warn "【#{spec.name} | #{spec.version}】组件二进制版本编译失败 ."
            end
          end

          success_specs = sources_sepc - fail_build_specs
          if success_specs.any?
            success_specs.uniq.each do |spec|
              UI.warn " =======【 #{spec.name} | #{spec.version} 】二进制组件制作完成 ！！！"
            end
          end
          # pod repo update
          UI.section("\nUpdating Spec Repositories\n".yellow) do
            Pod::Command::Bin::Repo::Update.new(CLAide::ARGV.new([])).run
          end
        end

        private

        def library_exist(spec)
          File.exist?(File.join(@local_build_dir, "lib#{spec.name}.a")) || is_framework(spec)
        end

        def is_framework(spec)
          res = File.exist?(File.join(@local_build_dir, "#{spec.name}.framework"))
          unless res
            res = File.exist?(File.join(CBin::Config::Builder.instance.xcode_BuildProductsPath_dir, "#{spec.name}","Swift Compatibility Header"))
          end
          res
        end

      end
    end
  end
end
