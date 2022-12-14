require 'macho'
require 'cocoapods'

module Pod
  class Sandbox
    class FileAccessor
     def dynamic_binary?(binary)
       @cached_dynamic_binary_results ||= {}
       return @cached_dynamic_binary_results[binary] unless @cached_dynamic_binary_results[binary].nil?
       return false unless binary.file?

       @cached_dynamic_binary_results[binary] = MachO.open(binary).dylib?
     rescue MachO::MachOError
       @cached_dynamic_binary_results[binary] = true

     end

    end
  end
end
