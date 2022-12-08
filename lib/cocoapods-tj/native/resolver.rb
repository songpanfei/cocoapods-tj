

require 'parallel'
require 'cocoapods'
require 'cocoapods-tj/native/podfile'
require 'cocoapods-tj/native/sources_manager'
require 'cocoapods-tj/native/installation_options'
require 'cocoapods-tj/gem_version'
require 'cocoapods-tj/command/bin/archive'

module Pod
  class Resolver
    if Pod.match_version?('~> 1.6')

      def aggregate_for_dependency(dependency)
        sources_manager = Config.instance.sources_manager
        if dependency&.podspec_repo
          sources_manager.aggregate_for_dependency(dependency)

        else
          @aggregate ||= Source::Aggregate.new(sources)
        end
      end
    end

    if Pod.match_version?('~> 1.4')
      def specifications_for_dependency(dependency, additional_requirements_frozen = [])
        additional_requirements = additional_requirements_frozen.dup.compact
        requirement = Requirement.new(dependency.requirement.as_list + additional_requirements.flat_map(&:as_list))
        if podfile.allow_prerelease? && !requirement.prerelease?
          requirement = Requirement.new(dependency.requirement.as_list.map { |r| r + '.a' } + additional_requirements.flat_map(&:as_list))
        end

        options = if Pod.match_version?('~> 1.7')
                    podfile.installation_options
                  else
                    installation_options
                  end

        if Pod.match_version?('~> 1.8')
          specifications = find_cached_set(dependency)
                           .all_specifications(options.warn_for_multiple_pod_sources, requirement)
        else
          specifications = find_cached_set(dependency)
                           .all_specifications(options.warn_for_multiple_pod_sources)
                           .select { |s| requirement.satisfied_by? s.version }
        end

        specifications
          .map { |s| s.subspec_by_name(dependency.name, false, true) }
          .compact
      end
    end

    if Pod.match_version?('~> 1.6')
      alias old_valid_possibility_version_for_root_name? valid_possibility_version_for_root_name?

      def valid_possibility_version_for_root_name?(requirement, activated, spec)
        return true if podfile.allow_prerelease?

        old_valid_possibility_version_for_root_name?(requirement, activated, spec)
      end
    elsif Pod.match_version?('~> 1.4')
      def requirement_satisfied_by?(requirement, activated, spec)
        version = spec.version
        return false unless requirement.requirement.satisfied_by?(version)

        shared_possibility_versions, prerelease_requirement = possibility_versions_for_root_name(requirement, activated)
        if !shared_possibility_versions.empty? && !shared_possibility_versions.include?(version)
          return false
        end
        if !podfile.allow_prerelease? && version.prerelease? && !prerelease_requirement
          return false
        end
        unless spec_is_platform_compatible?(activated, requirement, spec)
          return false
        end

        true
      end
    end

    # >= 1.4.0 才有 resolver_specs_by_target 以及 ResolverSpecification
    # >= 1.5.0 ResolverSpecification 才有 source，供 install 或者其他操作时，输入 source 变更
    #
    if Pod.match_version?('~> 1.4')
      old_resolver_specs_by_target = instance_method(:resolver_specs_by_target)
      define_method(:resolver_specs_by_target) do
        specs_by_target = old_resolver_specs_by_target.bind(self).call

        sources_manager = Config.instance.sources_manager
        use_source_pods = podfile.use_source_pods

        missing_binary_specs = []
        specs_by_target.each do |target, rspecs|
          use_binary_rspecs = if podfile.use_binaries? || podfile.use_binaries_selector
                                rspecs.select do |rspec|
                                  ([rspec.name, rspec.root.name] & use_source_pods).empty? &&
                                    (podfile.use_binaries_selector.nil? || podfile.use_binaries_selector.call(rspec.spec))
                                end
                              else
                                []
                              end

          specs_by_target[target] = rspecs.map do |rspec|


            use_binary = use_binary_rspecs.include?(rspec)
            source = use_binary ? sources_manager.binary_source : sources_manager.code_source

            spec_version = rspec.spec.version

            begin
              specification = source.specification(rspec.root.name, spec_version)
              UI.message "#{rspec.root.name} #{spec_version} \r\n specification =#{specification} "
              if rspec.spec.subspec?
                specification = specification.subspec_by_name(rspec.name, false, true)
              end

              next unless specification

              used_by_only = if Pod.match_version?('~> 1.7')
                               rspec.used_by_non_library_targets_only
                             else
                               rspec.used_by_tests_only
                             end

                rspec = if Pod.match_version?('~> 1.4.0')
                          ResolverSpecification.new(specification, used_by_only)
                        else
                          ResolverSpecification.new(specification, used_by_only, source)
                        end

              # end

            rescue Pod::StandardError => e

              # missing_binary_specs << rspec.spec if use_binary
              missing_binary_specs << rspec.spec
              rspec
            end

            rspec
          end.compact
        end

        if missing_binary_specs.any?
          missing_binary_specs.uniq.each do |spec|
            #UI.message "【#{spec.name} | #{spec.version}】组件无对应二进制版本 , 将采用源码依赖."
          end
          Pod::Command::Bin::Archive.missing_binary_specs(missing_binary_specs)

          sources_sepc = []
          des_dir = CBin::Config::Builder.instance.local_psec_dir
          FileUtils.rm_f(des_dir) if File.exist?des_dir
          Dir.mkdir des_dir unless File.exist?des_dir
          missing_binary_specs.uniq.each do |spec|
            next if spec.name.include?('/')

            spec_git_res = false
            CBin::Config::Builder.instance.ignore_git_list.each do |ignore_git|
              spec_git_res = spec.source[:git] && spec.source[:git].include?(ignore_git)
              break if spec_git_res
            end
            next if spec_git_res

            sources_sepc << spec
            unless spec.defined_in_file.nil?
              FileUtils.cp("#{spec.defined_in_file}", "#{des_dir}")
            end
          end
        end

        specs_by_target
      end
    end
  end

  if Pod.match_version?('~> 1.4.0')
    # 1.4.0 没有 spec_source
    class Specification
      class Set
        class LazySpecification < BasicObject
          attr_reader :spec_source

          old_initialize = instance_method(:initialize)
          define_method(:initialize) do |name, version, source|
            old_initialize.bind(self).call(name, version, source)

            @spec_source = source
          end

          def respond_to?(method, include_all = false)
            return super unless method == :spec_source

            true
          end
        end
      end
    end
  end
end
