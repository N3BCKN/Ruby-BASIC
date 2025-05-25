# Global variables on top
$token = ''  # stores current token
$buffer = {}  # Stores the program lines
$current_pos = 0  # current position for PRINT
$variables = {}
$line_number = 0  # Current line number
$goto = false     # GOTO flag
$for_loops = {}
$arrays = {}
$user_functions = {}
$gosub_stack = [] 


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

# Update the run function to handle GOTO
def run
  line_iterator = $buffer.keys.sort.each
  
  begin
    loop do
      if $goto == false
        $line_number = line_iterator.next
      else
        $goto = false
        current_iterator = $buffer.keys.sort.each
        current_line = current_iterator.next
        while $line_number != current_line
          current_line = current_iterator.next
        end
        line_iterator = current_iterator
      end
      line = $buffer[$line_number]
      execute($line_number, line)
    end
  rescue StopIteration
    # End of program
  rescue StandardError => e
    puts "Program terminated with error: #{e}"
  end
end

def execute(num, line)
  begin
    line_str = line.is_a?(Array) ? line.join : line.to_s
    
    # fandle full-line REM statements
    if line_str.strip.start_with?('REM')
      return  # simply ignore REM lines
    end
    
    # handle inline REM comments
    # find REM parts that are outside of string literals
    in_string = false
    rem_pos = -1
    
    (0...line_str.length - 2).each do |i|
      if line_str[i] == '"'
        in_string = !in_string
      elsif !in_string && i + 2 < line_str.length
        if line_str[i, 3].upcase == 'REM'
          rem_pos = i
          break
        end
      end
    end
    
    # if REM found, truncate the line
    if rem_pos >= 0
      line_str = line_str[0...rem_pos].strip
    end
    
    # handle multiple statements in the same line
    if line_str.include?(':')
     # find colon outside strings
        in_string = false
        real_colons = []
  
        line_str.chars.each_with_index do |char, i|
          if char == '"'
            in_string = !in_string
          elsif char == ':' && !in_string
            real_colons << i
          end
        end

      # if colons are found, split this line and do recursion
      unless real_colons.empty?
        first_part = line_str[0...real_colons[0]]
        second_part = line_str[(real_colons[0] + 1)..-1]

        # execute first line
        execute(num, first_part)
        # executre second line
        execute(num, second_part)
        return
      end
    end
    
    # continue with normal execution...
    line = line_str.chars if line.is_a?(String)

    scan(line)
    
    # save original line for possible assignment detection
    original_line = line.dup
    
    case $token
    when 'REM'
      # Do nothing for REM statements
      return 
    when 'PRINT'
      print_statement(line)
    when 'LET'
      let_statement(line)
    when 'GOTO'
      goto_statement(line)
    when 'IF'
      if_statement(num, line)
    when 'FOR'
      for_statement(line)
    when 'NEXT'
      next_statement(line)
    when 'DIM'
      dim_statement(line)
    when 'DEF'
      def_statement(line)
    when 'GOSUB'
      gosub_statement(line)
    when 'RETURN'
      return_statement(line)
    when 'END'
      end_statement(line)
    when ''
      # Empty line after processing - do nothing
      return
    else
      # Check if this starts with an existing variable name
      if $token.is_a?(String) && $variables.key?($token) && 
         line_str.include?('=')
        # This is an operation on an existing variable
        let_statement(original_line)
      else
        require 'byebug'
        byebug
        puts "Unknown statement: #{$token}"
      end
    end
  rescue StopIteration
    # Propagate StopIteration exception to run 
    raise
  rescue StandardError => e
    puts "Line #{num}: Execution failed! #{e}"
  end
end

def def_statement(line)
  line_text = line.is_a?(Array) ? line.join : line.to_s
  line_text.strip!
  
  # check format: DEF FN name(param) = expression
  unless line_text.start_with?('FN') && line_text.include?('=')
    puts "Invalid DEF FN syntax"
    raise "Invalid DEF FN syntax"
  end
  
  equals_pos = line_text.index('=')
  left_part = line_text[0...equals_pos].strip
  expression_part = line_text[(equals_pos + 1)..-1].strip
  
  # parse function name and parameters
  fn_part = left_part[2..-1].strip  # Remove "FN"
  
  open_paren = fn_part.index('(')
  close_paren = fn_part.index(')', open_paren)
  
  unless open_paren && close_paren
    puts "Invalid function definition"
    raise "Invalid function syntax"
  end
  
  function_name = fn_part[0...open_paren].strip
  params_text = fn_part[(open_paren + 1)...close_paren].strip
  parameters = params_text.empty? ? [] : params_text.split(',').map(&:strip)
  
  # store function definition
  $user_functions[function_name] = {
    'parameters' => parameters,
    'expression' => expression_part
  }
end

def call_user_function(function_name, arguments)
  unless $user_functions.key?(function_name)
    puts "Function #{function_name} not defined"
    return nil
  end
  
  function_def = $user_functions[function_name]
  parameters = function_def['parameters']
  expression_text = function_def['expression']
  
  # check argument count
  if arguments.length != parameters.length
    puts "Function #{function_name} expects #{parameters.length} arguments, got #{arguments.length}"
    return nil
  end
  
  # save current values of parameters if they exist as variables
  saved_values = {}
  parameters.each do |param|
    saved_values[param] = $variables[param] if $variables.key?(param)
  end
  
  # assign arguments to parameters
  parameters.each_with_index do |param, i|
    $variables[param] = arguments[i]
  end
  
  # evaluate function expression
  begin
    result = eval_expr(expression_text.chars)
  rescue StandardError => e
    puts "Error evaluating function: #{e}"
    result = nil
  end
  
  # restore original values
  parameters.each do |param|
    if saved_values.key?(param)
      $variables[param] = saved_values[param]
    else
      $variables.delete(param)
    end
  end
  
  result
end

def gosub_statement(line)
  line_text = line.is_a?(Array) ? line.join : line.to_s
  line_text.strip!
  
  # get target line number
  target_line = eval_expr(line_text.chars).to_i
  
  # save return position (next line)
  current_keys = $buffer.keys.sort
  current_index = current_keys.index($line_number)
  
  if current_index + 1 < current_keys.length
    return_line = current_keys[current_index + 1]
  else
    return_line = $line_number  # Last line, remember it
  end
  
  $gosub_stack.push(return_line)
  
  # jump to target line
  $line_number = target_line
  $goto = true
end

def return_statement(line)
  if $gosub_stack.empty?
    puts "RETURN without GOSUB"
    raise "RETURN without GOSUB"
  end
  
  return_line = $gosub_stack.pop
  $line_number = return_line
  $goto = true
end

def end_statement(line)
  $gosub_stack = []  # Clear GOSUB stack
  raise StopIteration  # Signal program end
end

def dim_statement(line)
  line_text = line.is_a?(Array) ? line.join : line.to_s
  line_text.strip!
  
  # format: DIM ARRAY(10, 20)
  open_paren = line_text.index('(')
  close_paren = line_text.index(')', open_paren)
  
  unless open_paren && close_paren
    puts "Invalid DIM statement syntax"
    raise "Invalid DIM syntax"
  end
  
  array_name = line_text[0...open_paren].strip
  dimensions_text = line_text[(open_paren + 1)...close_paren].strip
  dimensions = dimensions_text.split(',').map(&:strip)
  
  # convert dimensions to numbers
  dimension_values = dimensions.map do |dim|
    (eval_expr(dim.chars) + 1).to_i  # +1 as BASIC arrays are 0-based
  end
  
  # create the array
  $arrays[array_name] = create_array(dimension_values)
end

# helper to create multi-dimensional arrays
def create_array(dimensions)
  if dimensions.length == 1
    return [0] * dimensions[0]  # initialize with zeros
  else
    return Array.new(dimensions[0]) { create_array(dimensions[1..-1]) }
  end
end

def for_statement(line)
  line_text = line.is_a?(Array) ? line.join : line.to_s
  line_text.strip!
  
  # parse "FOR var = start TO end [STEP step]"
  unless line_text.include?('=') && line_text.include?('TO')
    puts "Invalid FOR syntax"
    raise "Invalid FOR syntax"
  end
  
  var_part, rest = line_text.split('=', 2)
  var_name = var_part.strip
  
  start_expr, to_part = rest.split('TO', 2)
  start_expr = start_expr.strip
  to_part = to_part.strip
  
  # handle optional STEP
  if to_part.include?('STEP')
    end_expr, step_expr = to_part.split('STEP', 2)
    end_expr = end_expr.strip
    step_expr = step_expr.strip
  else
    end_expr = to_part
    step_expr = "1"  # Default step is 1
  end
  
  # calculate values
  start_val = eval_expr(start_expr.chars)
  end_val = eval_expr(end_expr.chars)
  step_val = eval_expr(step_expr.chars)
  
  # initialize loop variable
  $variables[var_name] = start_val
  
  # find next line after FOR
  current_keys = $buffer.keys.sort
  current_index = current_keys.index($line_number)
  next_line = current_index + 1 < current_keys.length ? 
              current_keys[current_index + 1] : $line_number
  
  # store loop info
  $for_loops[var_name] = {
    "end" => end_val,
    "step" => step_val,
    "line" => next_line
  }
end

def next_statement(line)
  var_name = line.is_a?(Array) ? line.join.strip : line.to_s.strip
  
  unless $for_loops.key?(var_name)
    puts "FOR loop for variable '#{var_name}' not found"
    raise "FOR loop not found"
  end
  
  loop_info = $for_loops[var_name]
  
  # update loop variable
  $variables[var_name] += loop_info["step"]
  
  # check loop condition
  if (loop_info["step"] > 0 && $variables[var_name] <= loop_info["end"]) || 
     (loop_info["step"] < 0 && $variables[var_name] >= loop_info["end"])
    # continue loop - go back to line after FOR
    $line_number = loop_info["line"]
    $goto = true
  else
    # loop finished - remove loop info
    $for_loops.delete(var_name)
  end
end

def let_statement(line)
  line_text = line.is_a?(Array) ? line.join : line.to_s
  line_text.strip!
  
  # check if this is an array assignment
  if line_text.include?('(') && line_text.include?(')') && line_text.include?('=')
    equals_pos = line_text.index('=')
    array_part = line_text[0...equals_pos].strip
    expr_part = line_text[(equals_pos + 1)..-1].strip
    
    open_paren = array_part.index('(')
    close_paren = array_part.index(')')
    
    if open_paren && close_paren
      array_name = array_part[0...open_paren].strip
      
      unless $arrays.key?(array_name)
        puts "Array not defined: #{array_name}"
        raise "Array not defined"
      end
      
      # get indices
      indices_text = array_part[(open_paren + 1)...close_paren].strip
      indices = indices_text.split(',').map { |idx| eval_expr(idx.strip.chars) }
      
      value = eval_expr(expr_part.chars)
      
      # assign to array element
      set_array_value(array_name, indices, value)
      return
    end
  end
  
  # regular variable assignment
  if !line_text.include?('=')
    puts 'Missing "=" in variable definition!'
    raise "Missing equals sign"
  end
    
  parts = line_text.split('=', 2)
  var_name = parts[0].strip
  expr_text = parts[1].strip
  
  if expr_text.empty?
    puts 'Missing variable value!'
    raise "Missing value"
  else
    $variables[var_name] = eval_expr(expr_text.chars)
  end
end

def set_array_value(array_name, indices, value)
  array = $arrays[array_name]
  
  # navigate to the correct position
  (0...(indices.length - 1)).each do |i|
    index = indices[i]
    unless array.is_a?(Array) && index >= 0 && index < array.length
      raise "Array index out of bounds: #{index}"
    end
    array = array[index]
  end
  
  # set the value
  last_index = indices[-1]
  unless array.is_a?(Array) && last_index >= 0 && last_index < array.length
    raise "Array index out of bounds: #{last_index}"
  end
  
  array[last_index] = value
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

def goto_statement(line)
  line = line.is_a?(Array) ? line.join.strip.chars : line.to_s.strip.chars
  scan(line)
  target_line = expression(line)
  $line_number = target_line.to_i
  $goto = true
end

def if_statement(num, line)
  text = line.is_a?(Array) ? line.join : line.to_s
  
  # Find THEN and ELSE keywords
  then_index = text.index('THEN')
  else_index = text.index('ELSE', then_index + 4) if then_index
  
  if then_index.nil?
    puts 'Missing "THEN" after condition!'
    raise "Missing THEN keyword"
  end
  
  condition = text[0...then_index].strip
  
  if else_index
    # We have both THEN and ELSE
    then_action = text[(then_index + 4)...else_index].strip
    else_action = text[(else_index + 4)..-1].strip
    
    if evaluate_condition(condition)
      execute(num, then_action)
    else
      execute(num, else_action)
    end
  else
    # Only THEN, no ELSE
    action = text[(then_index + 4)..-1].strip
    
    if evaluate_condition(condition)
      execute(num, action)
    end
  end
end

def evaluate_condition(condition)
  COMPARISON_OPERATORS.each do |op, func|
    next unless condition.include?(op)
    
    left, right = condition.split(op, 2)
    return func.call(
      eval_expr(left.strip.chars), 
      eval_expr(right.strip.chars)
    )
  end
  
  # If no operator, check if value is non-zero
  eval_expr(condition.chars) != 0
end

# helper function for expression evaluation
def eval_expr(expr)
  scan(expr)
  expression(expr)
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
  return parse_user_function(line) if $token == 'FN'
  return parse_variable_or_array(line) if $token.is_a?(String) && !$token.empty?

  puts "Undefined token in factor: #{$token}"
  nil
end

def parse_user_function(line)
  scan(line)
  
  if !$token.is_a?(String)
    puts "Expected function name after FN"
    return nil
  end
  
  function_name = $token
  scan(line)
  
  if $token != '('
    puts "Expected '(' after function name"
    return nil
  end
  
  # get arguments
  arguments = []
  scan(line)  # skip '('
  
  while $token != ')'
    arg_value = expression(line)
    arguments << arg_value
    
    if $token == ','
      scan(line)  # skip comma
    elsif $token != ')'
      puts "Expected ',' or ')' in function call"
      return nil
    end
  end
  
  scan(line)  # skip ')'
  call_user_function(function_name, arguments)
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

def parse_variable_or_array(line)
  identifier = $token
  scan(line)
  
  # opening parenthesis means it could be an array
  if $token == '('
    # check if array exists
    if $arrays.key?(identifier)
      indices = get_indices(line)
      return nil if indices.nil?

      begin
        get_array_value(identifier, indices)
      rescue StandardError => e
        puts "Error accessing array #{identifier}: #{e}"
        nil
      end
    else
      puts "Array not defined: #{identifier}"
      nil
    end
  else
    # otherwise it's a variable
    return $variables[identifier] if $variables.key?(identifier)

    puts "Variable \"#{identifier}\" is not defined!"
    nil
  end
end

# helper functions for array access
def get_indices(line)
  scan(line)  # Skip '('
  indices = []
  
  while $token != ')'
    index_value = expression(line)
    indices << index_value.to_i
    
    if $token == ','
      scan(line)  # Skip comma
    elsif $token != ')'
      puts "Expected ',' or ')' in array index"
      return nil
    end
  end
  
  scan(line)  # skip ')'
  indices
end

def get_array_value(array_name, indices)
  array = $arrays[array_name]
  
  indices.each do |index|
    unless array.is_a?(Array) && index >= 0 && index < array.length
      raise "Array index out of bounds: #{index}"
    end
    array = array[index]
  end
  
  array
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