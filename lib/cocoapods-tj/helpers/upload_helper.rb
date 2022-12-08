

# copy from https://github.com/CocoaPods/cocoapods-packager

require 'cocoapods-tj/native/podfile'
require 'cocoapods/command/gen'
require 'cocoapods/generate'
require 'cocoapods-tj/helpers/framework_builder'
require 'cocoapods-tj/helpers/library_builder'
require 'cocoapods-tj/helpers/sources_helper'
require 'cocoapods-tj/command/bin/spec/push'

module CBin
  class Upload
    class Helper
      include CBin::SourcesHelper

      def initialize(spec,code_dependencies,sources)
        @spec = spec
        @code_dependencies = code_dependencies
        @sources = sources
      end

      def upload
        Dir.chdir(CBin::Config::Builder.instance.root_dir) do

          res_zip = curl_zip
          if res_zip
            filename = spec_creator
            push_binary_repo(filename)
          end
          res_zip
        end
      end

      def spec_creator
        spec_creator = CBin::SpecificationSource::Creator.new(@spec)
        spec_creator.create
        spec_creator.write_spec_file
        spec_creator.filename
      end

      def curl_zip
        zip_file = "#{CBin::Config::Builder.instance.library_file(@spec)}.zip"
        res = File.exist?(zip_file)
        unless res
          zip_file = CBin::Config::Builder.instance.framework_zip_file(@spec) + ".zip"
          res = File.exist?(zip_file)
        end
        if res
          `curl #{CBin.config.binary_upload_url} -F "name=#{@spec.name}" -F "version=#{@spec.version}" -F "annotate=#{@spec.name}_#{@spec.version}_log" -F "file=@#{zip_file}"` if res
        end

        res
      end


      # 上传二进制 podspec
      def push_binary_repo(binary_podsepc_json)
        argvs = [
            "#{binary_podsepc_json}",
            "--binary",
            "--sources=#{sources_option(@code_dependencies, @sources)},https:\/\/cdn.cocoapods.org",
            "--skip-import-validation",
            "--use-libraries",
            "--allow-warnings",
            "--verbose",
            "--code-dependencies"
        ]
        if @verbose
          argvs += ['--verbose']
        end

        push = Pod::Command::Bin::Repo::Push.new(CLAide::ARGV.new(argvs))
        push.validate!
        push.run
      end

    end
  end
end
