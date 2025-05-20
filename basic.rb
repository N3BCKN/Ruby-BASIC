require 'readline'

# Global variables on top
$buffer = {}  # Stores the program lines

def print_statement(line)
  line = line.is_a?(Array) ? line.join.strip.chars : line.to_s.strip.chars
  scan(line)
  
  # Track position for future features
  $current_pos = 0 if !defined?($current_pos)
  new_line = true  # Whether to add newline at the end
  
  while true
    if $token == ''
      break
    elsif $token.is_a?(String) && $token[0] == '"'
      # String literal
      text = $token[1..-2]  # Remove quotes
      print text
      $current_pos += text.length
      scan(line)
    else
      scan(line)  # Skip non-string tokens for now
    end
    
    # Check for separator
    if $token == ','
      print ' '  # Add space for comma
      $current_pos += 1
      scan(line)
    elsif $token == ';'
      # Semicolon - no space, suppress newline if at end
      scan(line)
      new_line = ($token != '')  # No newline if semicolon at end
    else
      break
    end
  end
  
  # Add newline unless suppressed by trailing semicolon
  if new_line
    puts
    $current_pos = 0
  end
end

# Enhanced main function with program management
def main
  puts "Ruby Altair Basic 0.0.1, 1975-#{Time.now.year}"
  puts "Type 'HELP' for available commands"

  loop do
    begin
      line = Readline.readline('> ', true)
      
      if !line.empty? && (Readline::HISTORY.length == 0 || Readline::HISTORY[-1] != line)
        Readline::HISTORY.push(line) 
      end

      case line
      when 'QUIT'
        break
      when 'NEW'
        $buffer = {}
      when 'LIST'
        if $buffer.empty?
          puts 'Program is empty'
        else
          $buffer.keys.sort.each do |num|
            puts "#{num} #{$buffer[num]}"
          end
        end
      when 'CLEAR'
        system('clear') if RUBY_PLATFORM =~ /linux|bsd|darwin/
        system('cls') if RUBY_PLATFORM =~ /mswin|mingw|cygwin/
      when 'HELP'
        puts "\nAvailable commands:"
        puts '  RUN      - Run the program (not implemented yet)'
        puts '  NEW      - Clear the program'
        puts '  LIST     - List the program'
        puts '  CLEAR    - Clear the screen'
        puts '  QUIT     - Exit the interpreter'
      else
        unless line.strip.empty?  # Skip empty lines
          parts = line.split(' ', 2)
          if parts[0].match?(/^\d+$/)  # Line starts with a number
            line_num = parts[0].to_i
            if parts.length > 1
              $buffer[line_num] = parts[1]  # Store the line
            elsif $buffer.key?(line_num)
              $buffer.delete(line_num)  # Remove the line if only number given
            end
          else
            puts "> #{line}"
          end
        end
      end 
    rescue Interrupt
      puts "\nInterrupted. Type 'QUIT' to exit."
    rescue StandardError => e
      puts "Unexpected error: #{e}"
  end
  end
end

main