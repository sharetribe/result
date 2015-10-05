# Result

A generic Result object.

Result can be either Success or Failure.

Success result contains the data that the operation returns.

Failure result contains the error (symbol or Exception) which describes the reason why the operation failed. In addition, Failure contains a human-readable error message for convenience and a data object, which may contain additional information about the error.

Results are chainable. You can perform 3 operation and then validate the result. Error in the middle of the chain stops the chain execution.

## Usage

### Success

```ruby
# result without data
res = Result::Success.new

# result with data
res = Result::Success.new({data: 123})
```

### Failure

```ruby
# empty failure
res = Result::Failure.new

# failure with error code
res = Result::Failure.new(:generic_error)

# failure from exception (there's also a shortcut for this pattern, `try`)
res =
  begin
    # JSON.parse throws, if input is not valid JSON
    Result::Success.new(JSON.parse(payload))
  rescue JSON::ParserError => e
    Result::Failure.new(e)
  end

# failure with error message
res = Result::Failure.new(:generic_error, "This is error message")
puts res.error_msg #=> "This is error message"

# error message is taken from the exception
ex = ArgumentError.new("Exception error message")
res = Result::Failure.new(ex)
puts res.error_msg #=> "Exception error message"

# failure can also contain additional data
res = Result::Failure.new(:unknown_error, "Unknown error occured", {reason: :unknown})

# error can be either nil, symbol or Exception
Result::Failure.new("string") #=> ArgumentError: Error must be either nil, String or Exception

# error codes :error and :success is reserved
Result::Failure.new(:error) #=> ArgumentError: The error code :error is reserved
```

### on

```ruby
# on success
Result::Success.new("abc")
  .on(:success) { |v|
    puts v #=> "abc"
  }.on(:error) {
    puts "error" # doesn't go here
  }

# on error
Result::Failure.new(:generic_error)
  .on(:success) { |v|
    puts v #=> "abc" # doesn't go here
  }.on(:error) {
    puts "error" #=> "error"
  }

# on specific error

Result::Failure.new(:specific_error)
  .on(:success) { |v|
    puts v #=> "abc" # doesn't go here
  .on(:specific_error) {
    puts "specific error" #=> "specific error"
  }.on(:error) {
    puts "error" # doesn't go here
  }
```

### Chaining

```ruby
# success
Result::Success.new(1)
  .and_then { |v|
    Result::Success.new(v + 1)
  }
  .and_then { |v|
    Result::Success.new(v * 2)
  }.on(:success) { |v|
    puts v #=> 4
  }

# error stops the chain
Result::Success.new(1)
  .and_then { |v|
    Result::Error.new(:some_error)
  }
  .and_then { |v|
    Result::Success.new(v + 1)
  }.on(:success) { |v|
    puts v # doesn't go here
  }.on(error) { |error, error_msg, data|
    error #=> :some_error
  }
```

### Utils

```ruby
# instead of begin/rescue...
res =
  begin
    # JSON.parse throws, if input is not valid JSON
    Result::Success.new(JSON.parse(payload))
  rescue JSON::ParserError => e
    Result::Failure.new(e)
  end

# ...you can use try helper
Result.try { JSON.parse("invalid JSON") }
#=> #<Result::Failure:0x007fd0d3b37440 @error_msg="757: unexpected token at 'invalid JSON'", @success=false, @data=nil, @error=#<JSON::ParserError: 757: unexpected token at 'invalid JSON'>>

Result.try { JSON.parse('{"valid_json": true}') }
#=> #<Result::Success:0x007fd0d3b26ff0 @success=true, @data={"valid_json"=>true}>
```
