require 'cocoapods-tj/native/sources_manager'
require 'cocoapods-tj/command/bin/repo/update'
require 'cocoapods/user_interface'

Pod::HooksManager.register('cocoapods-tj', :pre_install) do |_context, _|
  require 'cocoapods-tj/native'

  Pod::Command::Bin::Repo::Update.new(CLAide::ARGV.new([])).run

  if _context.podfile.plugins.keys.include?('cocoapods-tj') && _context.podfile.configuration_env == 'dev'
    dependencies = _context.podfile.dependencies
    dependencies.each do |d|
      next unless d.respond_to?(:external_source) &&
                  d.external_source.is_a?(Hash) &&
                  !d.external_source[:path].nil? &&
                  $ARGV[1] != 'archive'
      _context.podfile.set_use_source_pods d.name
    end
  end

  project_root = Pod::Config.instance.project_root
  path = File.join(project_root.to_s, 'BinPodfile')

  next unless File.exist?(path)

  contents = File.open(path, 'r:utf-8', &:read)
  podfile = Pod::Config.instance.podfile
  podfile.instance_eval do
    begin
      eval(contents, nil, path)
    rescue Exception => e
      message = "Invalid `#{path}` file: #{e.message}"
      raise Pod::DSLError.new(message, path, e, contents)
    end
  end
end

Pod::HooksManager.register('cocoapods-tj', :source_provider) do |context, _|
  sources_manager = Pod::Config.instance.sources_manager
  podfile = Pod::Config.instance.podfile

  if podfile
    added_sources = [sources_manager.code_source]
    if podfile.use_binaries? || podfile.use_binaries_selector
      added_sources << sources_manager.binary_source
      added_sources.reverse!
   end
    added_sources.each { |source| context.add_source(source) }
  end
end
