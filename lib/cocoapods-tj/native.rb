require 'cocoapods'

if Pod.match_version?('~> 1.4')
  require 'cocoapods-tj/native/podfile'
  require 'cocoapods-tj/native/installation_options'
  require 'cocoapods-tj/native/specification'
  require 'cocoapods-tj/native/path_source'
  require 'cocoapods-tj/native/analyzer'
  require 'cocoapods-tj/native/installer'
  require 'cocoapods-tj/native/podfile_generator'
  require 'cocoapods-tj/native/pod_source_installer'
  require 'cocoapods-tj/native/linter'
  require 'cocoapods-tj/native/resolver'
  require 'cocoapods-tj/native/source'
  require 'cocoapods-tj/native/validator'
  require 'cocoapods-tj/native/acknowledgements'
  require 'cocoapods-tj/native/sandbox_analyzer'
  require 'cocoapods-tj/native/podspec_finder'
  require 'cocoapods-tj/native/file_accessor'
  require 'cocoapods-tj/native/pod_target_installer'
  require 'cocoapods-tj/native/target_validator'

end
