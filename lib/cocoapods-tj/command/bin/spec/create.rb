require 'cocoapods-tj/helpers'

module Pod
  class Command
    class Bin < Command
      class Spec < Bin
        class Create < Spec
          self.summary = ''
          self.description = <<-DESC

          DESC

          def self.options
            [
              ['--platforms=ios', '生成二进制 spec 支持的平台'],
              ['--template-podspec=A.binary-template.podspec', '生成拥有 subspec 的二进制 spec 需要的模版 podspec, 插件会更改 version 和 source'],
              ['--no-overwrite', '不允许覆盖']
            ].concat(super)
          end

          def initialize(argv)
            @platforms = argv.option('platforms', 'ios')
            @allow_overwrite = argv.flag?('overwrite', true)
            @template_podspec = argv.option('template-podspec')
            @podspec = argv.shift_argument
            super
          end

          def run
            code_spec = Pod::Specification.from_file(spec_file)
            if template_spec_file
              template_spec = Pod::Specification.from_file(template_spec_file)
            end

            if binary_spec && !@allow_overwrite
            else
              spec_file = create_binary_spec_file(code_spec, template_spec)
            end
          end

          def template_spec_file
            @template_spec_file ||= begin
              if @template_podspec
                find_spec_file(@template_podspec)
              else
                binary_template_spec_file
              end
            end
          end

          def spec_file
            @spec_file ||= begin
              if @podspec
                find_spec_file(@podspec)
              else
                if code_spec_files.empty?
                  raise Informative, '当前目录下没有找到可用源码 podspec.'
                end

                code_spec_files.first
              end
            end
          end
        end
      end
    end
  end
end
