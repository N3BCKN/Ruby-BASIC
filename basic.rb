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
$data_values = []
$data_pointer = 0


COMPARISON_OPERATORS = {
  '<>' => ->(a, b) { a != b },
  '<=' => ->(a, b) { a <= b },
  '>=' => ->(a, b) { a >= b },
  '<'  => ->(a, b) { a < b },
  '>'  => ->(a, b) { a > b },
  '='  => ->(a, b) { a == b },
}

BUILT_IN_FUNCTIONS = {
  # Math functions (1 argument)
  'ABS' => [->(x) { x.abs }, 1],
  'SGN' => [->(x) { x < 0 ? -1 : (x == 0 ? 0 : 1) }, 1],
  'SQR' => [->(x) { Math.sqrt(x) }, 1],
  'INT' => [->(x) { x.floor }, 1],
  'LOG' => [->(x) { Math.log(x) }, 1],
  'EXP' => [->(x) { Math.exp(x) }, 1],
  'SIN' => [->(x) { Math.sin(x) }, 1],
  'COS' => [->(x) { Math.cos(x) }, 1],
  'TAN' => [->(x) { Math.tan(x) }, 1],
  'ATN' => [->(x) { Math.atan(x) }, 1],
  'LEN' => [->(x) { x.is_a?(String) ? x.length : x.to_s.length }, 1],
  
  # String functions (1 argument)
  'STR$' => [->(x) { x.to_s }, 1],
  'CHR$' => [->(x) { x.to_i.chr }, 1],
  
  # Special functions
  'RND' => [-> { rand }, 0],  # No arguments
  'VAL' => [nil, 1],          # Special handling
  'LEFT$' => [nil, 2],        # Special handling
  'RIGHT$' => [nil, 2],       # Special handling
  'MID$' => [nil, 3]          # Special handling
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
  # reset global values
  $goto = false
  $for_loops = {}
  $gosub_stack = []
  $data_values = []
  $data_pointer = 0
  
  # first pass - collect all DATA
  $buffer.keys.sort.each do |num|
    line = $buffer[num]
    line_list = line.chars
    scan(line_list)
    if $token == 'DATA'
      data_statement(line_list)
    end
  end
  
  # second pass - normal execution
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
    # end of program
  rescue StandardError => e
    puts "Program terminated with error: #{e}"
  end
end

def execute(num, line)
  begin
    line_str = normalize_line(line)
    
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
    when 'DATA'
      data_statement(line)  # in normal execution, just skip
    when 'READ'
      read_statement(line)
    when 'RESTORE'
      restore_statement(line)
    when 'INPUT'
      input_statement(line) 
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

def input_statement(line)
  line_text = normalize_line(line)
  line_text.strip!
  
  # check for prompt string
  prompt = ""
  var_name = ""
  
  if line_text.start_with?('"')
    closing_quote = line_text.index('"', 1)
    
    if closing_quote
      prompt = line_text[1...closing_quote]
      remaining = line_text[(closing_quote + 1)..-1].strip
      
      if remaining.start_with?(';')
        var_name = remaining[1..-1].strip
      else
        var_name = remaining
      end
    end
  else
    var_name = line_text
  end
  
  # display prompt if exists
  print prompt unless prompt.empty?
  
  # get user input
  user_input = gets.chomp
  
  # convert to appropriate type
  if user_input.include?('.')
    value = user_input.to_f
  else
    begin
      value = Integer(user_input)  # use Integer() to properly convert to integer
    rescue ArgumentError
      value = user_input.to_f  # try float if integer fails
    end
  end
  
  # assign value (handling arrays too)
  if var_name.include?('(') && var_name.include?(')')
    # array element
    open_paren = var_name.index('(')
    close_paren = var_name.index(')')
    array_name = var_name[0...open_paren].strip
    
    unless $arrays.key?(array_name)
      puts "Array not defined: #{array_name}"
      raise "Array not defined"
    end
    
    indices_text = var_name[(open_paren + 1)...close_paren].strip
    indices = indices_text.split(',').map do |idx|
      idx_val = idx.strip
      if $variables.key?(idx_val)
        $variables[idx_val].to_i
      else
        idx_val.to_i
      end
    end
    
    set_array_value(array_name, indices, value)
  else
    # regular variable
    var_name = var_name.gsub(/\s+/, '')  # remove all whitespace
    $variables[var_name] = value
  end
end

# implement DATA statement (collect data values)
def data_statement(line)
  line_text = normalize_line(line)
  line_text.strip!
  
  # skip if empty
  return if line_text.empty?
  
  # split values by commas (respecting strings)
  values = []
  current_value = ''
  in_quotes = false
  
  line_text.each_char do |char|
    if char == '"'
      in_quotes = !in_quotes
      current_value += char
    elsif char == ',' && !in_quotes
      # end of value
      values << current_value.strip
      current_value = ''
    else
      current_value += char
    end
  end
  
  # add the last value
  values << current_value.strip unless current_value.strip.empty?
  
  # process and add values to data_values array
  values.each do |value|
    next if value.empty?
    
    if value.start_with?('"') && value.end_with?('"')
      # string - remove quotes
      $data_values << value[1..-2]
    else
      # try to convert to number
      begin
        if value.include?('.')
          $data_values << value.to_f
        else
          $data_values << value.to_i
        end
      rescue
        # use as string if conversion fails
        $data_values << value
      end
    end
  end
end
# implement READ statement
def read_statement(line)
  line_text = normalize_line(line)
  line_text.strip!
  
  # split variable names
  var_names = line_text.split(',').map(&:strip)
  
  var_names.each do |var_name|
    next if var_name.empty?
    
    # check if we have enough data
    if $data_pointer >= $data_values.length
      puts "Out of DATA - READ beyond available data"
      raise "Out of DATA"
    end
    
    # assign value to variable
    $variables[var_name] = $data_values[$data_pointer]
    $data_pointer += 1
  end
end
# implement RESTORE statement
def restore_statement(line)
  line_text = normalize_line(line)
  line_text.strip!
  
  # reset data pointer
  $data_pointer = 0
  
end

def def_statement(line)
  line_text = normalize_line(line)
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
  line_text = normalize_line(line)
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
  line_text = normalize_line(line)
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
  line_text = normalize_line(line)
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
  var_name = normalize_line(line)
  
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
  line_text = normalize_line(line)
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
  line = normalize_line(line).chars
  scan(line)
  
  $current_pos = 0 if !defined?($current_pos)
  new_line = true
  
  while true
    if $token == ''
      break
    elsif $token.is_a?(String) && $token[0] == '"'
      # handle string
      text = $token[1..-2]  # remove quotes
      print text
      $current_pos += text.length
      scan(line)
    else
      # for any non-string token, treat it as the start of an expression
      result = expression(line)
      unless result.nil?
        # handle TAB function
        if result.is_a?(Array) && result[0] == 'TAB'
          target_pos = result[1]
          # Only move forward, never backward
          if $current_pos < target_pos
            spaces = ' ' * (target_pos - $current_pos)
            print spaces
            $current_pos = target_pos
          end
        else
          # normal result
          print result
          $current_pos += result.to_s.length
        end
      end
    end
    
    # handle separators
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
  line = normalize_line(line).chars
  scan(line)
  target_line = expression(line)
  $line_number = target_line.to_i
  $goto = true
end

def if_statement(num, line)
  text = normalize_line(line)
  
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
  return parse_tab(line) if $token == 'TAB'
  return parse_builtin_function(line) if BUILT_IN_FUNCTIONS.key?($token)  
  return parse_variable_or_array(line) if $token.is_a?(String) && !$token.empty?

  puts "Undefined token in factor: #{$token}"
  nil
end

def parse_tab(line)
  scan(line)
  
  if $token != '('
    puts "Expected '(' after TAB"
    return nil
  end
  
  scan(line)  # Skip '('
  col_position = expression(line)
  
  if col_position.nil?
    return nil
  end
  
  if $token != ')'
    puts "Expected ')' after TAB argument"
    return nil
  end
  
  scan(line)  # Skip ')'
  
  # Return a special format that print_statement can recognize
  return ['TAB', col_position.to_i]
end

def parse_builtin_function(line)
  func_name = $token
  func_def, arg_count = BUILT_IN_FUNCTIONS[func_name]
  scan(line)
  
  # Handle RND (no arguments needed)
  if func_name == 'RND'
    # Optional parentheses for RND
    if $token == '('
      scan(line)  # Skip '('
      if $token == ')'
        scan(line)  # Skip ')'
      else
        # If argument provided, use it but ignore value
        expression(line)
        scan(line) if $token == ')'
      end
    end
    return rand  # Always return random value between 0 and 1
  end
  
  # Standard function with arguments
  if $token != '('
    puts "Expected '(' after #{func_name}"
    return nil
  end
  
  if arg_count == 1
    # Single argument
    scan(line)  # Skip '('
    arg_value = expression(line)
    
    if $token != ')'
      puts "Expected ')' after #{func_name} argument"
      return nil
    end
    scan(line)  # Skip ')'
    
    # Special handling for VAL
    if func_name == 'VAL'
      begin
        if arg_value.is_a?(String)
          return arg_value.include?('.') ? arg_value.to_f : arg_value.to_i
        end
        return arg_value
      rescue
        puts "Cannot convert '#{arg_value}' to number"
        return 0
      end
    end
    
    # Standard function
    begin
      return func_def.call(arg_value)
    rescue => e
      puts "Error in #{func_name}: #{e}"
      return nil
    end
  else
    # Multiple argument functions (LEFT$, RIGHT$, MID$)
    args = []
    scan(line)  # Skip '('
    
    arg_count.times do |i|
      # Get argument
      arg_value = expression(line)
      args << arg_value
      
      # Check separator
      if i < arg_count - 1
        if $token != ','
          puts "Expected ',' after argument #{i+1}"
          return nil
        end
        scan(line)  # Skip ','
      end
    end
    
    if $token != ')'
      puts "Expected ')' after arguments"
      return nil
    end
    scan(line)  # Skip ')'
    
    # Process string functions
    begin
      string_arg = args[0].to_s
      
      case func_name
      when 'LEFT$'
        n = args[1].to_i
        return string_arg[0...n]
      when 'RIGHT$'
        n = args[1].to_i
        return n > 0 ? string_arg[-n..-1] : ''
      when 'MID$'
        start = args[1].to_i - 1  # BASIC starts at 1
        length = args[2].to_i
        return string_arg[start, length]
      end
    rescue => e
      puts "Error in #{func_name}: #{e}"
      return ''
    end
  end
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

def normalize_line(line)
  line.is_a?(Array) ? line.join.strip : line.to_s.strip
end

def save_file(filename)
  # add .bas extension if it's not there 
  filename = "#{filename}.bas" unless filename.downcase.end_with?('.bas')
  
  begin
    File.open(filename, 'w') do |f|
      $buffer.keys.sort.each do |num| # fetch data from buffer to file 
        f.puts "#{num} #{$buffer[num]}"
      end
    end
    puts "Program saved to #{filename}"
    return true
  rescue StandardError => e
    puts "Failed to save file: #{e}"
    return false
  end
end 

def load_file(filename)
  # check file extension
  unless filename.downcase.end_with?('.bas')
    puts "Error: Only .bas files are supported"
    return false
  end
  
  begin
    File.open(filename, 'r') do |f|
      $buffer = {}  # reset buffer
      f.read.split("\n").each do |line|
        begin
          next if line.strip.empty?  # skip empty lines
          parts = line.split(' ', 2)
          next if !parts[0].match?(/^\d+$/)  # skip lines without numbers
          
          num = parts[0].to_i
          src = parts.length > 1 ? parts[1] : ""
          $buffer[num] = src
        rescue StandardError => e
          puts "Error parsing line: #{line}, #{e}"
        end
      end
    end
    puts "Program loaded from #{filename}"
    return true
  rescue StandardError => e
    puts "Failed to load file: #{e}"
    return false
  end
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
      when 'LOAD'
        print 'Filename: '
        filename = gets.chomp
        load_file(filename)
      when 'SAVE'
        print 'Filename: '
        filename = gets.chomp
        save_file(filename)
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
        puts '  RUN      - Run the program'
        puts '  NEW      - Clear the program'
        puts '  LIST     - List the program'
        puts '  LOAD     - Load a program from file (.bas)'
        puts '  SAVE     - Save program to file (.bas)'
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