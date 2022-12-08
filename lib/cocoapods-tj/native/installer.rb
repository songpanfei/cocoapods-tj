

require 'parallel'
require 'cocoapods'
require 'cocoapods-tj/native/pod_source_installer'

module Pod
  class Installer
    alias old_create_pod_installer create_pod_installer
    def create_pod_installer(pod_name)
      installer = old_create_pod_installer(pod_name)
      installer.installation_options = installation_options
      installer
    end

    alias old_install_pod_sources install_pod_sources
    def install_pod_sources
      if installation_options.install_with_multi_threads
        if Pod.match_version?('~> 1.4.0')
          install_pod_sources_for_version_in_1_4_0
        elsif Pod.match_version?('~> 1.5')
          install_pod_sources_for_version_above_1_5_0
        else
          old_install_pod_sources
        end
      else
        old_install_pod_sources
        end
    end

    # rewrite install_pod_sources
    def install_pod_sources_for_version_in_1_4_0
      @installed_specs = []
      pods_to_install = sandbox_state.added | sandbox_state.changed
      title_options = { verbose_prefix: '-> '.green }
      Parallel.each(root_specs.sort_by(&:name), in_threads: 4) do |spec|
        if pods_to_install.include?(spec.name)
          if sandbox_state.changed.include?(spec.name) && sandbox.manifest
            previous = sandbox.manifest.version(spec.name)
            title = "Installing #{spec.name} #{spec.version} (was #{previous})"
          else
            title = "Installing #{spec}"
          end
          UI.titled_section(title.green, title_options) do
            install_source_of_pod(spec.name)
          end
        else
          UI.titled_section("Using #{spec}", title_options) do
            create_pod_installer(spec.name)
          end
        end
      end
    end

    def install_pod_sources_for_version_above_1_5_0
      @installed_specs = []
      pods_to_install = sandbox_state.added | sandbox_state.changed
      title_options = { verbose_prefix: '-> '.green }

      Parallel.each(root_specs.sort_by(&:name), in_threads: 4) do |spec|
        if pods_to_install.include?(spec.name)
          if sandbox_state.changed.include?(spec.name) && sandbox.manifest
            current_version = spec.version
            previous_version = sandbox.manifest.version(spec.name)
            has_changed_version = current_version != previous_version
            current_repo = analysis_result.specs_by_source.detect do |key, values|
              break key if values.map(&:name).include?(spec.name)
            end
            current_repo &&= current_repo.url || current_repo.name
            previous_spec_repo = sandbox.manifest.spec_repo(spec.name)
            has_changed_repo = !previous_spec_repo.nil? && current_repo && (current_repo != previous_spec_repo)
            title = "Installing #{spec.name} #{spec.version}"
            if has_changed_version && has_changed_repo
              title += " (was #{previous_version} and source changed to `#{current_repo}` from `#{previous_spec_repo}`)"
              end
            if has_changed_version && !has_changed_repo
              title += " (was #{previous_version})"
              end
            if !has_changed_version && has_changed_repo
              title += " (source changed to `#{current_repo}` from `#{previous_spec_repo}`)"
              end
          else
            title = "Installing #{spec}"
          end
          UI.titled_section(title.green, title_options) do
            install_source_of_pod(spec.name)
          end
        else
          UI.titled_section("Using #{spec}", title_options) do
            create_pod_installer(spec.name)
          end
        end
      end
    end
  end

  module Downloader
    class Cache
      @@lock = Mutex.new
      alias old_ensure_matching_version ensure_matching_version
      def ensure_matching_version
        @@lock.synchronize { old_ensure_matching_version }
      end
    end
  end
end
