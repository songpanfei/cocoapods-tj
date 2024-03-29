
require 'cocoapods-tj/helpers/framework.rb'
require 'English'
require 'cocoapods-tj/config/config_builder'
require 'shellwords'
require 'cocoapods-tj/helpers/build_utils'

module CBin
  class Framework
    class Builder
      include Pod
      def initialize(spec, file_accessor, platform, source_dir, isRootSpec = true, build_model="Debug")
        @spec = spec
        @source_dir = source_dir
        @file_accessor = file_accessor
        @platform = platform
        @build_model = build_model
        @isRootSpec = isRootSpec
        vendored_static_frameworks = file_accessor.vendored_static_frameworks.map do |framework|
          path = framework
          extn = File.extname  path
          if extn.downcase == '.framework'
            path = File.join(path,File.basename(path, extn))
          end
          path
        end

        @vendored_libraries = (vendored_static_frameworks + file_accessor.vendored_static_libraries).map(&:to_s)
      end

      def build
        defines = compile
        build_sim_libraries(defines)

        defines
      end

      def lipo_build(defines)

        if CBin::Build::Utils.is_swift_module(@spec) || !CBin::Build::Utils.uses_frameworks?
          UI.section("Building static Library #{@spec}") do

            output = framework.versions_path + Pathname.new(@spec.name)

            build_static_library_for_ios(output)

            copy_headers
            copy_license
            copy_resources

            cp_to_source_dir
          end
        else
            UI.section("Building framework  #{@spec}") do

              output = framework.fwk_path + Pathname.new(@spec.name)

              copy_static_framework_dir_for_ios

              build_static_framework_machO_for_ios(output)

              copy_framework_resources


          end
        end

        framework
      end

      private

      def cp_to_source_dir
        framework.remove_current_version if CBin::Build::Utils.is_swift_module(@spec)

        framework_name = "#{@spec.name}.framework"
        target_dir = File.join(CBin::Config::Builder.instance.zip_dir,framework_name)
        FileUtils.rm_rf(target_dir) if File.exist?(target_dir)

        zip_dir = CBin::Config::Builder.instance.zip_dir
        FileUtils.mkdir_p(zip_dir) unless File.exist?(zip_dir)

        `cp -fa #{@platform}/#{framework_name} #{target_dir}`
      end

      def build_sim_libraries(defines)
        UI.message 'Building simulator libraries'

        archs = ios_architectures_sim
        archs.map do |arch|
          xcodebuild(defines, "-sdk iphonesimulator ARCHS=\'#{arch}\' ", "build-#{arch}",@build_model)
        end

      end


      def static_libs_in_sandbox(build_dir = 'build')
        file = Dir.glob("#{build_dir}/lib#{target_name}.a")
        unless file
          UI.warn "file no find = #{build_dir}/lib#{target_name}.a"
        end
        file
      end

      def build_static_library_for_ios(output)
        UI.message "Building ios libraries with archs #{ios_architectures}"
        static_libs = static_libs_in_sandbox('build') + static_libs_in_sandbox('build-simulator') + @vendored_libraries

        ios_architectures.map do |arch|
          static_libs += static_libs_in_sandbox("build-#{arch}") + @vendored_libraries
        end
        ios_architectures_sim do |arch|
          static_libs += static_libs_in_sandbox("build-#{arch}") + @vendored_libraries
        end

        build_path = Pathname("build")
        build_path.mkpath unless build_path.exist?

        libs = (ios_architectures + ios_architectures_sim) .map do |arch|
          library = "build-#{arch}/lib#{@spec.name}.a"
          library
        end

        UI.message "lipo -create -output #{output} #{libs.join(' ')}"
        `lipo -create -output #{output} #{libs.join(' ')}`
      end

      def ios_build_options
        "ARCHS=\'#{ios_architectures.join(' ')}\' OTHER_CFLAGS=\'-fembed-bitcode -Qunused-arguments\'"
      end

      def ios_architectures

        archs = %w[arm64 armv7]

        archs
      end

      def ios_architectures_sim

        archs = %w[x86_64]
        # TODO 处理是否需要 i386
        archs
      end

      def compile
        defines = "GCC_PREPROCESSOR_DEFINITIONS='$(inherited)'"
        defines += ' '
        defines += @spec.consumer(@platform).compiler_flags.join(' ')

        options = ios_build_options
          archs = ios_architectures
          archs.map do |arch|
            xcodebuild(defines, "ARCHS=\'#{arch}\' OTHER_CFLAGS=\'-fembed-bitcode -Qunused-arguments\'","build-#{arch}",@build_model)
          end


        defines
      end

      def is_debug_model
        @build_model == "Debug"
      end

      def target_name

         if @spec.available_platforms.count > 1
           "#{@spec.name}-#{Platform.string_name(@spec.consumer(@platform).platform_name)}"
         else
            @spec.name
         end
      end

      def xcodebuild(defines = '', args = '', build_dir = 'build', build_model = 'Debug')

        unless File.exist?("Pods.xcodeproj") #cocoapods-generate v2.0.0
          command = "xcodebuild #{defines} #{args} CONFIGURATION_BUILD_DIR=#{File.join(File.expand_path("..", build_dir), File.basename(build_dir))} clean build -configuration #{build_model} -target #{target_name} -project ./Pods/Pods.xcodeproj 2>&1"
        else
          command = "xcodebuild #{defines} #{args} CONFIGURATION_BUILD_DIR=#{build_dir} clean build -configuration #{build_model} -target #{target_name} -project ./Pods.xcodeproj 2>&1"
        end

        UI.message "command = #{command}"
        output = `#{command}`.lines.to_a

        if $CHILD_STATUS.exitstatus != 0
          raise <<~EOF
            Build command failed: #{command}
            Output:
            #{output.map { |line| "    #{line}" }.join}
          EOF

          Process.exit
        end
      end

      def copy_headers
        public_headers = Array.new

        spec_header_dir = "./Headers/Public/#{@spec.name}"
        unless File.exist?(spec_header_dir)
          spec_header_dir = "./Pods/Headers/Public/#{@spec.name}"
        end
        raise "copy_headers #{spec_header_dir} no exist " unless File.exist?(spec_header_dir)
        Dir.chdir(spec_header_dir) do
          headers = Dir.glob('*.h')
          headers.each do |h|
            public_headers << Pathname.new(File.join(Dir.pwd,h))
          end
        end
        # end


        public_headers.each do |h|
          `ditto #{h} #{framework.headers_path}/#{h.basename}`
        end

        if !@spec.module_map.nil?
          module_map_file = @file_accessor.module_map
          if Pathname(module_map_file).exist?
            module_map = File.read(module_map_file)
          end
        elsif public_headers.map(&:basename).map(&:to_s).include?("#{@spec.name}-umbrella.h")
          module_map = <<-MAP
          framework module #{@spec.name} {
            umbrella header "#{@spec.name}-umbrella.h"

            export *
            module * { export * }
          }
          MAP
        end

        unless module_map.nil?
          UI.message "Writing module map #{module_map}"
          unless framework.module_map_path.exist?
            framework.module_map_path.mkpath
          end
          File.write("#{framework.module_map_path}/module.modulemap", module_map)

          archs = ios_architectures + ios_architectures_sim
          archs.map do |arch|
            swift_module = "build-#{arch}/#{@spec.name}.swiftmodule"
            if File.directory?(swift_module)
              FileUtils.cp_r("#{swift_module}/.", framework.swift_module_path)
            end
          end
          swift_Compatibility_Header = "build-#{archs.first}/Swift\ Compatibility\ Header/#{@spec.name}-Swift.h"
          FileUtils.cp(swift_Compatibility_Header,framework.headers_path) if File.exist?(swift_Compatibility_Header)
          info_plist_file = File.join(File.dirname(__FILE__),"info.plist")
          FileUtils.cp(info_plist_file,framework.fwk_path)
        end
      end

      def copy_swift_header

      end

      def copy_license
        license_file = @spec.license[:file] || 'LICENSE'
        `cp "#{license_file}" .` if Pathname(license_file).exist?
      end

      def copy_resources
        resource_dir = './build/*.bundle'
        resource_dir = './build-armv7/*.bundle' if File.exist?('./build-armv7')
        resource_dir = './build-arm64/*.bundle' if File.exist?('./build-arm64')

        bundles = Dir.glob(resource_dir)

        bundle_names = [@spec, *@spec.recursive_subspecs].flat_map do |spec|
          consumer = spec.consumer(@platform)
          consumer.resource_bundles.keys +
              consumer.resources.map do |r|
                File.basename(r, '.bundle') if File.extname(r) == 'bundle'
              end
        end.compact.uniq

        bundles.select! do |bundle|
          bundle_name = File.basename(bundle, '.bundle')
          bundle_names.include?(bundle_name)
        end

        if bundles.count > 0
          UI.message "Copying bundle files #{bundles}"
          bundle_files = bundles.join(' ')
          `cp -rp #{bundle_files} #{framework.resources_path} 2>&1`
        end

        real_source_dir = @source_dir
        unless @isRootSpec
          spec_source_dir = File.join(Dir.pwd,"#{@spec.name}")
          unless File.exist?(spec_source_dir)
            spec_source_dir = File.join(Dir.pwd,"Pods/#{@spec.name}")
          end
          raise "copy_resources #{spec_source_dir} no exist " unless File.exist?(spec_source_dir)

          spec_source_dir = File.join(Dir.pwd,"#{@spec.name}")
          real_source_dir = spec_source_dir
        end

        resources = [@spec, *@spec.recursive_subspecs].flat_map do |spec|
          expand_paths(real_source_dir, spec.consumer(@platform).resources)
        end.compact.uniq

        if resources.count == 0 && bundles.count == 0
          framework.delete_resources
          return
        end

        if resources.count > 0
          escape_resource = []
          resources.each do |source|
            escape_resource << Shellwords.join(source)
          end
          UI.message "Copying resources #{escape_resource}"
          `cp -rp #{escape_resource.join(' ')} #{framework.resources_path}`
        end
      end

      def expand_paths(source_dir, path_specs)
        path_specs.map do |path_spec|
          Dir.glob(File.join(source_dir, path_spec))
        end
      end

      def build_static_framework_machO_for_ios(output)
        UI.message "Building ios framework with archs #{ios_architectures}"

        static_libs = static_libs_in_sandbox('build') + @vendored_libraries
        ios_architectures.map do |arch|
          static_libs += static_libs_in_sandbox("build-#{arch}") + @vendored_libraries
        end

        ios_architectures_sim do |arch|
          static_libs += static_libs_in_sandbox("build-#{arch}") + @vendored_libraries
        end

        build_path = Pathname("build")
        build_path.mkpath unless build_path.exist?

        libs = (ios_architectures + ios_architectures_sim) .map do |arch|
          library = "build-#{arch}/#{@spec.name}.framework/#{@spec.name}"
          library
        end

        UI.message "lipo -create -output #{output} #{libs.join(' ')}"
        `lipo -create -output #{output} #{libs.join(' ')}`
      end

      def copy_static_framework_dir_for_ios

        archs = ios_architectures + ios_architectures_sim
        framework_dir = "build-#{ios_architectures_sim.first}/#{@spec.name}.framework"
        framework_dir = "build-#{ios_architectures.first}/#{@spec.name}.framework" unless File.exist?(framework_dir)
        unless File.exist?(framework_dir)
          raise "#{framework_dir} path no exist"
        end
        File.join(Dir.pwd, "build-#{ios_architectures_sim.first}/#{@spec.name}.framework")
        FileUtils.cp_r(framework_dir, framework.root_path)

        archs.map do |arch|
          swift_module = "build-#{arch}/#{@spec.name}.framework/Modules/#{@spec.name}.swiftmodule"
          if File.directory?(swift_module)
            FileUtils.cp_r("#{swift_module}/.", framework.swift_module_path)
          end
        end

        framework.remove_current_version
      end

      def copy_framework_resources
        resources = Dir.glob("#{framework.fwk_path + Pathname.new('Resources')}/*")
        if resources.count == 0
          framework.delete_resources
        end
      end



      def framework
        @framework ||= begin
          framework = Framework.new(@spec.name, @platform.name.to_s)
          framework.make
          framework
        end
      end


    end
  end
end
