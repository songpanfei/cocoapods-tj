require 'yaml'
require 'cocoapods-tj/config/config_hot_key'

module CBin
  class Config_Hot_Key
    class Asker
      def show_prompt
        print ' > '.green
      end

      def ask_with_answer(question, pre_answer, selection)
        print "\n#{question}\n"

        print_selection_info = lambda {
          print "可选值：[ #{selection.join(' / ')} ]\n" if selection
        }
        print_selection_info.call
        print "旧值：#{pre_answer}\n" unless pre_answer.nil?

        answer = ''
        loop do
          show_prompt
          answer = STDIN.gets.chomp.strip

          if answer == '' && !pre_answer.nil?
            answer = pre_answer
            print answer.yellow
            print "\n"
          end

          next if answer.empty?
          break if !selection || selection.include?(answer)

          print_selection_info.call
        end

        answer
      end

      def wellcome_message

      end

      def done_message
      end
    end
  end
end
