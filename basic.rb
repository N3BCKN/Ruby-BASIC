require 'readline'

# Global variables on top
$token = ''  # stores current token
$buffer = {}  # Stores the program lines
$current_pos = 0  # current position for PRINT

# Scan a line of BASIC code to extract the next token
def scan(line)
  # Skip whitespace
  line.shift while !line.empty? && line[0] == ' '
  
  return $token = '' if line.empty?
  
  if line[0] =~ /\d/  # Numbers
    $token = number(line)
  elsif line[0] =~ /[A-Z]/  # Keywords and identifiers
    $token = get_identifier(line)
  elsif line[0] =~ /[+\-*\/\(\)=<>,;:\^]/  # Operators
    $token = line.shift
  elsif line[0] == '"'  # Strings
    $token = string(line)
  else
    puts "Unexpected character: #{line[0]}"
    $token = ''
    line.shift
  end
end

# parse number
def number(line)
  tok = ''
  has_decimal = false
  
  # parse digits and at most one decimal point
  while !line.empty? && (line[0] =~ /\d/ || (line[0] == '.' && !has_decimal))
    has_decimal = true if line[0] == '.'
    tok += line.shift
  end
 

  if has_decimal
    tok.to_f
  else
    tok.to_i
  end
end

# parse a string literal
def string(line)
  msg = ''
  line.shift  # skip opening quote
  while !line.empty? && line[0] != '"'
    msg += line.shift
  end
  
  if line.empty?
    puts 'Missing closing quote!'
    raise 'Missing closing quote'
  else
    line.shift  # skip closing quote
    '"' + msg + '"'  # return with quotes for identification
  end
end

# parse an identifier
def get_identifier(line)
  name = ''
  # first position must be capital letter
  if !line.empty? && line[0] =~ /[A-Z]/
    name += line.shift
    # subsequent positions can be capital letters or digits
    while !line.empty? && (line[0] =~ /[A-Z0-9]/)
      name += line.shift
    end
    # check for type suffix ($, %, #, !)
    if !line.empty? && line[0] =~ /[\$\%\#\!]/
      name += line.shift
    end
  end
  name
end

def execute(num, line)
  begin
    line = line.chars if line.is_a?(String)
    scan(line)
    
    case $token
    when 'PRINT'
      print_statement(line)
    else
      puts "Unknown statement: #{$token}"
    end
  rescue StandardError => e
    puts "Line #{num}: Execution failed! #{e}"
  end
end

def run
  $buffer.keys.sort.each do |num| 
    line = $buffer[num]
    execute(num, line)
  end
end

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
      when 'RUN'
        run
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
          if parts[0].match?(/^\d+$/)
            line_num = parts[0].to_i
            if parts.length > 1
              $buffer[line_num] = parts[1]
            elsif $buffer.key?(line_num)
              $buffer.delete(line_num)
            end
          else
            execute(0, line) # add execute function here
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