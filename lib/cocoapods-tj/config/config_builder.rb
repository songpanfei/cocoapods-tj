require 'yaml'

module CBin
  class Config
    class Builder

      include Pod

      def self.instance
        @instance ||= new
      end

      def initialize
        load_build_config
        # clean
      end

      # 加载配置项
      def load_build_config
        @white_pod_list = []
        @ignore_git_list = []
        project_root = Pod::Config.instance.project_root
        path = File.join(project_root.to_s, 'BinArchive.json')

        if File.exist?(path)
          config = JSON.parse(File.read(path))
          @white_pod_list = config['archive-white-pod-list']
          UI.warn "====== archive-white-pod-list = #{@white_pod_list}" if @white_pod_list
          @ignore_git_list = config['ignore-git-list']
          UI.warn "====== ignore_git_list = #{@ignore_git_list}" if @ignore_git_list
          @ignore_http_list = config['ignore-http-list']

          @xcode_build_name = config['xcode_build_path']
          @root_dir = config['root_dir'] unless config['root_dir'].nil?
        end

      end

      def clean
        #清除之前的缓存
        FileUtils.rm_rf(Dir.glob("#{zip_dir}/*")) if File.exist?(zip_dir)
        FileUtils.rm_rf(Dir.glob("#{binary_json_dir}/*")) if File.exist?(binary_json_dir)
        FileUtils.rm_rf(Dir.glob("#{local_psec_dir}/*")) if File.exist?(local_psec_dir)
      end

      def gen_name
        'bin-archive'
      end

      def gen_dir
        @gen_dir ||= begin
                       dir = File.join(root_dir,gen_name)
                       Dir.mkdir(dir) unless File.exist?dir
                       Pathname.new(dir)
                     end
      end


      def framework_name(spec)
        "#{spec.name}.framework"
      end

      def framework_name_version(spec)
        "#{spec.name}.framework_#{spec.version}"
      end

      def framework_zip_file(spec)
        File.join(zip_dir_name, framework_name_version(spec))
      end

      def framework_file(spec)
        File.join(zip_dir_name, framework_name(spec))
      end

      def library_name(spec)
        library_name_version(spec.name, spec.version)
      end

      def library_name_version(name,version)
        "bin_#{name}_#{version}"
      end
      def library_file(spec)
        File.join(zip_dir_name, library_name(spec))
      end

      def zip_dir_name
        "bin-zip"
      end

      def zip_dir
        @zip_dir ||= begin
                       dir = File.join(root_dir,zip_dir_name)
                       Dir.mkdir(dir) unless File.exist?dir
                       Pathname.new(dir)
                     end
      end

      def local_spec_dir_name
        "bin-spec"
      end

      def local_psec_dir
        @local_psec_dir ||= begin
                               dir = File.join(root_dir,local_spec_dir_name)
                               Dir.mkdir(dir) unless File.exist?dir
                               Pathname.new(dir)
                             end
      end

      def binary_json_dir_name
        "bin-json"
      end

      def binary_json_dir
        @binary_json_dir ||= begin
                       dir = File.join(root_dir,binary_json_dir_name)
                       Dir.mkdir(dir) unless File.exist?dir
                       Pathname.new(dir)
                     end
      end


      def target_name
        @target_name ||= begin
                           target_name_str =  Pod::Config.instance.podfile.root_target_definitions.first.children.first.to_s
                           target_name_str[5,target_name_str.length]
                         end
      end

      def xcode_build_name
        @xcode_build_name ||= begin
                                  project_root = Pod::Config.instance.project_root
                                  path = File.join(project_root.to_s, 'BinArchive.json')

                                  if File.exist?(path)
                                    config = JSON.parse(File.read(path))
                                    @xcode_build_name = config['xcode_build_path']
                                  end
                                  if @xcode_build_name.nil? || Dir.exist?(@xcode_build_name)
                                    @xcode_build_name = "xcode-build/Build/Intermediates.noindex/ArchiveIntermediates/#{target_name}/IntermediateBuildFilesPath/UninstalledProducts/iphoneos/"
                                  end
                                  puts @xcode_build_name
                                  @xcode_build_name
                              end
      end

      def xcode_build_dir
        @xcode_build_dir ||= begin
                                temp_xcode_build_name = xcode_build_name
                                if File.exist?(temp_xcode_build_name)
                                    Pathname.new(temp_xcode_build_name)
                                else
                                    dir = File.join(root_dir,xcode_build_name)
                                    Pathname.new(dir)
                                end
                             end
      end

      def xcode_BuildProductsPath_dir
        @xcode_BuildProductsPath_dir ||= begin
                                           temp_xcode_BuildProductsPath_dir = "xcode-build/Build/Intermediates.noindex/ArchiveIntermediates/#{target_name}/BuildProductsPath/"
                                           full_path = File.join(root_dir, temp_xcode_BuildProductsPath_dir)

                                           if (File.exist?(full_path))
                                             Dir.chdir(full_path) do
                                               iphoneos = Dir.glob('*-iphoneos')
                                               if iphoneos.length > 0
                                                 full_path = File.join(full_path,iphoneos.first)
                                               else
                                               end
                                             end
                                           end
                                           Pathname.new(full_path)
                                         end
      end

      def root_dir
        @root_dir ||= begin
                         basename = File.basename(Pod::Config.instance.installation_root)
                         parent_dir = File.dirname(Pod::Config.instance.installation_root)
                         root_name = File.join(parent_dir,"#{basename}-build-temp")
                         Dir.mkdir(root_name) unless File.exist?root_name
                         Pathname.new(root_name)
                       end

      end

      def white_pod_list
        @white_pod_list
      end
      def ignore_git_list
        @ignore_git_list
      end

      def ignore_http_list
        @ignore_http_list
      end

    end
  end
end
