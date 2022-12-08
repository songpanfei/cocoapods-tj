
require 'cocoapods'
require 'cocoapods-tj/native/podfile_env'
require 'cocoapods-tj/native/podfile'

module Pod
  class Command
    class Bin < Command
      class Update < Bin
        include Pod
        include Pod::Podfile::DSL

        self.summary = ''

        self.description = <<-DESC
        DESC
        def self.options
          [
            ["--sources=#{Pod::TrunkSource::TRUNK_REPO_URL}", 'The sources from which to update dependent pods. ' \
              'Multiple sources must be comma-delimited'],
            ['--exclude-pods=podName', 'Pods to exclude during update. Multiple pods must be comma-delimited'],
            ['--clean-install', 'Ignore the contents of the project cache and force a full pod installation. This only ' \
              'applies to projects that have enabled incremental installation'],
            ['--project-directory=/project/dir/', 'The path to the root of the project directory'],
            ['--no-repo-update', 'Skip running `pod repo update` before install']
          ].concat(super)
        end

        def initialize(argv)
          @update = argv.flag?('update')
          super
          @additional_args = argv.remainder!
        end

        def run
          Update.load_local_podfile

          argvs = [
            *@additional_args
          ]

          gen = Pod::Command::Update.new(CLAide::ARGV.new(argvs))
          gen.validate!
          gen.run
        end

        def self.load_local_podfile

          project_root = Pod::Config.instance.project_root
          path = File.join(project_root.to_s, 'Podfile_TJ')
          unless File.exist?(path)
            path = File.join(project_root.to_s, 'Podfile_TJ')
          end

          if File.exist?(path)
            contents = File.open(path, 'r:utf-8', &:read)

            podfile = Pod::Config.instance.podfile
            local_podfile = Podfile.from_file(path)

            if local_podfile
              local_pre_install_callback = nil
              local_post_install_callback = nil
              local_podfile.instance_eval do
                local_pre_install_callback = @pre_install_callback
                local_post_install_callback = @post_install_callback
              end
            end

            podfile.instance_eval do
              begin

                if local_podfile.plugins.any?
                  hash_plugins = podfile.plugins || {}
                  hash_plugins = hash_plugins.merge(local_podfile.plugins)
                  set_hash_value(%w[plugins].first, hash_plugins)

                  podfile.set_use_source_pods(local_podfile.use_source_pods) if local_podfile.use_source_pods
                  podfile.use_binaries!(local_podfile.use_binaries?)
                end

                local_podfile&.target_definition_list&.each do |local_target|
                  next if local_target.name == 'Pods'

                  target_definition_list.each do |target|

                    unless target.name == local_target.name &&
                        (local_target.to_hash['dependencies'] &&local_target.to_hash['dependencies'].any?)
                      next
                    end



                    target.instance_exec do

                      local_dependencies = local_target.to_hash['dependencies']
                      target_dependencies = target.to_hash['dependencies']

                      local_dependencies.each do |local_dependency|
                        unless local_dependency.is_a?(Hash) && local_dependency.keys.first
                          next
                        end

                        target_dependencies.each do |target_dependency|
                          next unless target_dependency.is_a?(Hash) &&
                                      target_dependency.keys.first &&
                                      target_dependency.keys.first == local_dependency.keys.first

                          target_dependencies.delete target_dependency
                          break
                        end
                      end
                      local_dependencies.each do |d|
                        UI.message "Development Pod #{d.to_yaml}"
                        if podfile.plugins.keys.include?('cocoapods-tj')
                          podfile.set_use_source_pods(d.keys.first) if (d.is_a?(Hash) && d.keys.first)
                        end
                      end
                      new_dependencies = target_dependencies + local_dependencies
                      set_hash_value(%w[dependencies].first, new_dependencies)

                    end
                  end

                end

                if local_pre_install_callback
                  @pre_install_callback = local_pre_install_callback
                end
                if local_post_install_callback
                  @post_install_callback = local_post_install_callback
                end
              rescue Exception => e
                message = "Invalid `#{path}` file: #{e.message}"
                raise Pod::DSLError.new(message, path, e, contents)
              end
            end

          end
        end
      end
    end
  end
end
