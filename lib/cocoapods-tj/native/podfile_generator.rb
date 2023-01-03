

require 'parallel'
require 'cocoapods'
require 'cocoapods-tj/native/pod_source_installer'


require 'parallel'
require 'cocoapods'

module Pod
  module Generate
    class PodfileGenerator
      # alias old_podfile_for_spec podfile_for_spec

      def podfile_for_spec(spec)
        generator = self
        dir = configuration.gen_dir_for_pod(spec.name)

        Pod::Podfile.new do
          project "#{spec.name}.xcodeproj"
          workspace "#{spec.name}.xcworkspace"

          plugin 'cocoapods-generate'

          install! 'cocoapods', generator.installation_options

          generator.podfile_plugins.each do |name, options|
            plugin(*[name, options].compact)
          end

          use_frameworks!(generator.configuration.use_frameworks?)

          if (supported_swift_versions = generator.supported_swift_versions)
            supports_swift_versions(supported_swift_versions)
          end

          # Explicitly set sources
          generator.configuration.sources.each do |source_url|
            source(source_url)
          end

          self.defined_in_file = dir.join('CocoaPods.podfile.yaml')

          test_specs = spec.recursive_subspecs.select(&:test_specification?)
          app_specs = if spec.respond_to?(:app_specification?)
                        spec.recursive_subspecs.select(&:app_specification?)
                      else
                        []
                      end

          spec_platform_names = spec.available_platforms.map(&:string_name).flatten.each.reject do |platform_name|
            !generator.configuration.platforms.nil? && !generator.configuration.platforms.include?(platform_name.downcase)
          end

          spec_platform_names.sort.each do |platform_name|
            target "App-#{platform_name}" do
              current_target_definition.swift_version = generator.swift_version if generator.swift_version
            end
          end


          inhibit_all_warnings! if generator.inhibit_all_warnings?
          use_modular_headers! if generator.use_modular_headers?


          pod_options = generator.dependency_compilation_kwargs(spec.name)
          pod_options[:path] = spec.defined_in_file.relative_path_from(dir).to_s


          { testspecs: test_specs, appspecs: app_specs }.each do |key, specs|
            pod_options[key] = specs.map { |s| s.name.sub(%r{^#{Regexp.escape spec.root.name}/}, '') }.sort unless specs.empty?
          end

          pod spec.name, **pod_options

          if Pod::Config.instance.podfile
            target_definitions['Pods'].instance_exec do
              target_definition = nil
              Pod::Config.instance.podfile.target_definition_list.each do |target|
                if target.label == "Pods-#{spec.name}"
                  target_definition = target
                  break
                end
              end
              if(target_definition && target_definition.use_modular_headers_hash.values.any?)
                target_definition.use_modular_headers_hash.values.each do |f|
                  f.each { | pod_name|  self.set_use_modular_headers_for_pod(pod_name, true) }
                end
              end


              if target_definition
                value = target_definition.to_hash['dependencies']
                next if value.blank?
                value.each do |f|
                  if f.is_a?(Hash) && f.keys.first == spec.name
                    value.delete f
                    break
                  end
                end
                old_value = self.to_hash['dependencies'].first
                value << old_value unless (old_value == nil || value.include?(old_value))

                set_hash_value(%w(dependencies).first, value)

                value = target_definition.to_hash['configuration_pod_whitelist']
                next if value.blank?
                set_hash_value(%w(configuration_pod_whitelist).first, value)


              end


            end

          end


          next if generator.configuration.local_sources.empty?
          generator.transitive_local_dependencies(spec, generator.configuration.local_sources).each do |dependency, podspec_file|
            pod_options = generator.dependency_compilation_kwargs(dependency.name)
            pod_options[:path] = if podspec_file[0] == '/' # absolute path
                                   podspec_file
                                 else
                                   '../../' + podspec_file
                                 end
            pod dependency.name, **pod_options
          end
        end
      end
    end
  end
end

