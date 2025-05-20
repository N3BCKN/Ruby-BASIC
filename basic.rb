# Interactive shell - the entry point to our interpreter
require 'readline'

def main
  puts "Ruby Altair Basic 0.0.1, 1975-#{Time.now.year}"
  puts "Type 'HELP' for available commands"

  loop do
    line = Readline.readline('> ', true)
    
    # add non empty lines to history 
    if !line.empty? && (Readline::HISTORY.length == 0 || Readline::HISTORY[-1] != line)
      Readline::HISTORY.push(line) 
    end 

    case line
    when 'QUIT'
      break
    when 'CLEAR'
      system('clear') if RUBY_PLATFORM =~ /linux|bsd|darwin/
      system('cls') if RUBY_PLATFORM =~ /mswin|mingw|cygwin/
    when 'HELP'
      puts "\nAvailable commands:"
      puts '  RUN      - Run the program (not implemented yet)'
      puts '  NEW      - Clear the program (not implemented yet)'
      puts '  LIST     - List the program (not implemented yet)'
      puts '  CLEAR    - Clear the screen'
      puts '  QUIT     - Exit the interpreter'
    else
      puts "> #{line}"
    end
  end
end

main