
require 'cocoapods-tj/config/config_hot_key_asker'

module Pod
  class Command
    class Bin < Command
      class Inithk < Bin
        self.summary = ''
        self.description = <<-DESC

        DESC

        def self.options
          [
            ['--bin-url=URL', '配置文件地址，直接从此地址下载配置文件']
          ].concat(super)
        end

        def initialize(argv)
          @bin_url = argv.option('bin-url')
          super
        end

        def run
          if @bin_url.nil?
            config_with_asker
          else
            config_with_url(@bin_url)
          end
        end

        private

        def config_with_url(url)
          require 'open-uri'

          file = open(url)
          contents = YAML.safe_load(file.read)

          CBin.config_hot_key.sync_config(contents.to_hash)
        rescue Errno::ENOENT => e
          raise Informative, "配置文件路径 #{url} 无效，请确认后重试."
        end

        def config_with_asker
          asker = CBin::Config_Hot_Key::Asker.new
          asker.wellcome_message

          config = {}
          template_hash = CBin.config_hot_key.template_hash
          template_hash.each do |k, v|
            default = begin
                        CBin.config_hot_key.send(k)
                      rescue StandardError
                        nil
                      end
            config[k] = asker.ask_with_answer(v[:description], default, v[:selection])
          end

          CBin.config_hot_key.sync_config(config)
          asker.done_message
        end
      end
    end
  end
end
