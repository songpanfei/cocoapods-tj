
require 'cocoapods-tj/command/bin/initHotKey'
require 'cocoapods-tj/command/bin/init'
require 'cocoapods-tj/command/bin/archive'
require 'cocoapods-tj/command/bin/auto'
require 'cocoapods-tj/command/bin/code'
require 'cocoapods-tj/command/bin/local'
require 'cocoapods-tj/command/bin/update'
require 'cocoapods-tj/command/bin/install'
require 'cocoapods-tj/command/bin/imy'

require 'cocoapods-tj/helpers'

module Pod
  class Command
    class Bin < Command
      include CBin::SourcesHelper
      include CBin::SpecFilesHelper

      self.abstract_command = true

      self.default_subcommand = 'open'
      self.summary = '组件二进制化插件.'
      self.description = <<-DESC

      DESC

      def initialize(argv)
        require 'cocoapods-tj/native'

        @help = argv.flag?('help')
        super
      end

      def validate!
        super

        banner! if @help
      end
    end
  end
end
