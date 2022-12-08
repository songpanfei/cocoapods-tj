
module Pod
  class Command
    class Bin < Command
      class Code < Bin
        self.summary = ''

        self.description = <<-DESC

        DESC

        self.arguments = [
            CLAide::Argument.new('NAME', false)
        ]
        def self.options
          [
              ['--all-clean', '删除所有已经下载的源码'],
              ['--clean', '删除所有指定下载的源码'],
              ['--list', '展示所有一级下载的源码以及其大小'],
              ['--source', '源码路径，本地路径,会去自动链接本地源码']
          ]
        end

        def initialize(argv)
          @codeSource =  argv.option('source') || nil
          @names = argv.arguments! unless argv.arguments.empty?
          @list = argv.flag?('list', false )
          @all_clean = argv.flag?('all-clean', false )
          @clean = argv.flag?('clean', false )

          @config = Pod::Config.instance

          super
        end


        def run

          podfile_lock = File.join(Pathname.pwd,"Podfile.lock")
          raise "podfile.lock,不存在，请先pod install/update" unless File.exist?(podfile_lock)
          @lockfile ||= Lockfile.from_file(Pathname.new(podfile_lock) )

          if @list
            list
          elsif @clean
            clean
          elsif @all_clean
            all_clean
          elsif @names
            add
          end

          if @list && @clean && @names
            raise "请选择您要执行的命令。"
          end
        end


        def add
          if @names == nil
            raise "请输入要调试组件名，多个组件名称用空格分隔"
          end

          @names.each do  |name|
            lib_file = get_lib_path(name)
            unless File.exist?(lib_file)
              raise "找不到 #{lib_file}"
            end
            UI.puts "#{lib_file}"

            target_path =  @codeSource || download_source(name)

            link(lib_file,target_path,name)
          end
        end

        def download_source(name)
          target_path =  File.join(source_root, name)
          UI.puts target_path
          FileUtils.rm_rf(target_path)

          find_dependency = find_dependency(name)

          spec = fetch_external_source(find_dependency, @config.podfile,@config.lockfile, @config.sandbox,true )

          download_request = Pod::Downloader::Request.new(:name => name, :spec => spec)
          Downloader.download(download_request, Pathname.new(target_path), :can_cache => true)

          target_path
        end

        def find_dependency (name)
          find_dependency = nil
          @config.podfile.dependencies.each do |dependency|
            if dependency.root_name.downcase == name.downcase
              find_dependency = dependency
              break
            end
          end
          find_dependency
        end


        def fetch_external_source(dependency ,podfile , lockfile, sandbox,use_lockfile_options)
          source = ExternalSources.from_dependency(dependency, podfile.defined_in_file, true)
          source.fetch(sandbox)
        end



        def link(lib_file,target_path,basename)
          dir = (`dwarfdump "#{lib_file}" | grep "AT_comp_dir" | head -1 | cut -d \\" -f2 `)
          sub_path = "#{basename}/bin-archive/#{basename}"
          dir = dir.gsub(sub_path, "").chomp

          unless File.exist?(dir)
            begin
              FileUtils.mkdir_p(dir)
            rescue SystemCallError
              array = dir.split('/')
              if array.length > 3
                root_path = '/' + array[1] + '/' + array[2]
                unless File.exist?(root_path)
                  raise "由于权限不足，请手动创建#{root_path} 后重试"
                end
              end
            end
          end

          if Pathname.new(lib_file).extname == ".a"
            FileUtils.rm_rf(File.join(dir,basename))
            `ln -s #{target_path} #{dir}`
          else
            FileUtils.rm_rf(File.join(dir,basename))
            `ln -s #{target_path} #{dir}/#{basename}`
          end

          check(lib_file,dir,basename)
        end

        def check(lib_file,dir,basename)
          file = `dwarfdump "#{lib_file}" | grep -E "DW_AT_decl_file.*#{basename}.*\\.m|\\.c" | head -1 | cut -d \\" -f2`
          if File.exist?(file)
            raise "#{file} 不存在 请检测代码源是否正确~"
          end
          UI.puts "link successfully!"
          UI.puts "view linked source at path: #{dir}"
        end

        def get_lib_path(name)
          dir = Pathname.new(File.join(Pathname.pwd,"Pods",name))
          lib_name = "lib#{name}.a"
          lib_path = File.join(dir,lib_name)

          unless File.exist?(lib_path)
            lib_path = File.join(dir.children.first,lib_name)
          end

          lib_path
        end

        def list
          Dir.entries(source_root).each do |sub|
            UI.puts "- #{sub}" unless sub.include?('.')
          end
          UI.puts "加载完成"
        end

        def all_clean
          FileUtils.rm_rf(source_root) if File.directory?(source_root)
          UI.puts "清理完成 #{source_root}"
        end

        def clean
          raise "请输入要删除的组件库" if @names.nil?
          @names.each do  |name|
            full_path = File.join(source_root,name)
            if File.directory?(full_path)
              FileUtils.rm_rf(full_path)
            else
              UI.puts "找不到 #{full_path}".yellow
            end
          end
          UI.puts "清理完成 #{@names.to_s}"
        end

        private

        def source_root
          dir = File.join(@config.cache_root,"Source")
          FileUtils.mkdir_p(dir) unless File.exist? dir
          dir
        end

      end
    end
  end
end
