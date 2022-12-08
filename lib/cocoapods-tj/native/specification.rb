

require 'cocoapods-tj/native/sources_manager'

module Pod
  class Specification
    VALID_EXTNAME = %w[.binary.podspec.json .binary.podspec .podspec.json .podspec].freeze
    DEFAULT_TEMPLATE_EXTNAME = %w[.binary-template.podspec .binary-template.podspec.json].freeze
  end
end
