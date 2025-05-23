# Global variables on top
$token = ''  # stores current token
$buffer = {}  # Stores the program lines
$current_pos = 0  # current position for PRINT
$variables = {}


COMPARISON_OPERATORS = {
  '<>' => ->(a, b) { a != b },
  '<=' => ->(a, b) { a <= b },
  '>=' => ->(a, b) { a >= b },
  '<'  => ->(a, b) { a < b },
  '>'  => ->(a, b) { a > b },
  '='  => ->(a, b) { a == b },
}

# Scan a line of BASIC code to extract the next token
def scan(line)
  # Skip whitespace
  line.shift while !line.empty? && line[0] == ' '
  
  return $token = '' if line.empty?
  
  if line[0] =~ /\d/  # Numbers
    $token = number(line)
  elsif line[0] =~ /[A-Z]/  # Keywords and identifiers
    $token = get_identifier(line)
  elsif line[0] =~ /[+\-*\/\(\)=<>,;:\^&|~]/  # Operators z
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

def run
  $buffer.keys.sort.each do |num| 
    line = $buffer[num]
    execute(num, line)
  end
end

def execute(num, line)
  begin
    line_str = line.is_a?(Array) ? line.join : line.to_s
    line = line_str.chars if line.is_a?(String)
    
    # Save original line for possible assignment detection
    original_line = line.dup
    
    scan(line)
    
    case $token
    when 'PRINT'
      print_statement(line)
    when 'LET'
      let_statement(line)
    else
      # Check if this starts with an existing variable name
      if $token.is_a?(String) && $variables.key?($token) && 
         line_str.include?('=')
        # This is an operation on an existing variable
        let_statement(original_line)
      else
        puts "Unknown statement: #{$token}"
      end
    end
  rescue StandardError => e
    puts "Line #{num}: Execution failed! #{e}"
  end
end

def let_statement(line)
  line_text = line.is_a?(Array) ? line.join : line.to_s
  line_text.strip!
  
  if !line_text.include?('=')
    puts 'Missing "=" in variable definition!'
    raise "Missing equals sign"
  end
    
  # Split into variable name and expression
  parts = line_text.split('=', 2)
  var_name = parts[0].strip
  expr_text = parts[1].strip
  
  if expr_text.empty?
    puts 'Missing variable value!'
    raise "Missing value"
  else
    # Convert expression to char array for parsing
    expr_list = expr_text.chars
    scan(expr_list)
    value = expression(expr_list)
    $variables[var_name] = value
  end
end

def print_statement(line)
  line = line.is_a?(Array) ? line.join.strip.chars : line.to_s.strip.chars
  scan(line)
  
  $current_pos = 0 if !defined?($current_pos)
  new_line = true
  
  while true
    if $token == ''
      break
    elsif $token.is_a?(String) && $token[0] == '"'
      # Obsługa ciągów znaków
      text = $token[1..-2]  # Usuń cudzysłowy
      print text
      $current_pos += text.length
      scan(line)
    else
      # Obsługa wyrażeń - pełna ewaluacja z operacjami matematycznymi
      result = expression(line)
      unless result.nil?
        print result
        $current_pos += result.to_s.length
      end
    end
    
    # Obsługa separatorów
    if $token == ','
      print ' '
      $current_pos += 1
      scan(line)
    elsif $token == ';'
      scan(line)
      new_line = ($token != '')
    else
      break
    end
  end
  
  if new_line
    puts
    $current_pos = 0
  end
end

def expression(line)
  bitwise_or(line)
end

def bitwise_or(line)
  a = bitwise_and(line)
  return nil if a.nil?
  
  while $token == '|' || $token == 'OR'
    op = $token
    scan(line)
    b = bitwise_and(line)
    return nil if b.nil?
    
    # bitwise OR for integers, logical OR for others
    if op == '|' || op == 'OR'
      if a.is_a?(Integer) && b.is_a?(Integer)
        a = a | b  # bitwise OR
      else
        a = (a != 0 || b != 0) ? 1 : 0  # logical OR
      end
    end
  end
  a
end

def bitwise_and(line)
  a = comparison(line)
  return nil if a.nil?
  
  while $token == '&' || $token == 'AND'
    op = $token
    scan(line)
    b = comparison(line)
    return nil if b.nil?
    
    # bitwise AND for integers, logical AND for others
    if op == '&' || op == 'AND'
      if a.is_a?(Integer) && b.is_a?(Integer)
        a = a & b  # bitwise AND
      else
        a = (a != 0 && b != 0) ? 1 : 0  # logical AND
      end
    end
  end
  a
end 


# def bitwise_and(line)
#   a = comparison(line)  # Zmiana tutaj - wywołuj comparison zamiast add_sub
#   return nil if a.nil?
#   while $token == '&' || $token == 'AND'
#     op = $token
#     scan(line)
#     b = comparison(line)  # I tutaj też
#     return nil if b.nil?  
#     if a.is_a?(Integer) && b.is_a?(Integer)
#       a = a & b
#     else
#       a = (a != 0 && b != 0) ? 1 : 0
#     end
#   end
#   a
# end
# 

def comparison(line)
  a = add_sub(line)
  return nil if a.nil?

  if COMPARISON_OPERATORS.key?($token)
    op = $token
    operator_func = COMPARISON_OPERATORS[op]
    scan(line)
    b = add_sub(line)
    return nil if b.nil?
    
    a = operator_func.call(a, b) ? 1 : 0
  end
  a
end


def add_sub(line)
  a = term(line)
  return nil if a.nil?
  
  while $token == '+' || $token == '-'
    op = $token
    scan(line)
    b = term(line)
    return nil if b.nil?
    
    if op == '+'
      a += b
    else  # op == '-'
      a -= b
    end
  end
  a
end

def term(line)
  a = power(line)
  return nil if a.nil?
  
  while $token == '*' || $token == '/'
    op = $token
    scan(line)
    b = power(line)
    return nil if b.nil?
    
    if op == '*'
      a *= b
    else  # op == '/'
      if b == 0
        puts 'Division by zero error!'
        return nil
      end
      a = a.to_f / b.to_f
    end
  end
  a
end

def power(line)
  a = factor(line)
  return nil if a.nil?
  
  if $token == '^'
    scan(line)
    b = power(line)  # for chained operations (2^3^2)
    return nil if b.nil?
    a **= b
  end
  a
end

def factor(line)
  return parse_number(line) if $token.is_a?(Integer) || $token.is_a?(Float)
  return parse_string(line) if $token.is_a?(String) && $token.start_with?('"')
  return parse_not(line) if $token == 'NOT' || $token == '~'
  return parse_parenthesized_expr(line) if $token == '('
  return parse_negative(line) if $token == '-'
  return parse_variable(line) if $token.is_a?(String) && !$token.empty?

  puts "Undefined token in factor: #{$token}"
  nil
end

def parse_number(line)
  value = $token
  scan(line)
  value
end

def parse_string(line)
  value = $token[1..-2] # remove question marks 
  scan(line)
  value
end

def parse_not(line)
  scan(line)
  a = factor(line)
  return nil if a.nil?

  if a.is_a?(Integer)
    ~a
  else
    (a != 0 ? 0 : 1)
  end
end

def parse_parenthesized_expr(line)
  scan(line)
  a = expression(line)
  return nil if a.nil?

  if $token != ')'
    puts 'Missing closing parenthesis!'
    return nil
  end

  scan(line)
  a
end

def parse_negative(line)
  scan(line)
  a = factor(line)
  a.nil? ? nil : -a
end

def parse_variable(line)
  identifier = $token
  scan(line)

  return $variables[identifier] if $variables.key?(identifier)

  puts "Variable \"#{identifier}\" is not defined!"
  nil
end

# Enhanced main function with program management
def main
  puts "Ruby Altair Basic 0.0.1, 1975-#{Time.now.year}"
  puts "Type 'HELP' for available commands"

  loop do
    begin
      print '> '
      line = gets.chomp

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
        $variables = {}
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