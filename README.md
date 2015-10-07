# Result

A generic Result object.

Result can be either Success or Failure.

Success result contains the data that the operation returns.

Failure result contains the error (symbol or Exception) which describes the reason why the operation failed. In addition, Failure contains a human-readable error message for convenience and a data object, which may contain additional information about the error.

Results are chainable. Failure in the middle of the chain stops the execution.

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

# failure from exception (there's also a shortcut for this pattern, see Adapters)
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
  }.on(:failure) {
    puts "error" # doesn't go here
  }

# on error
Result::Failure.new(:generic_error)
  .on(:success) { |v|
    puts v #=> "abc" # doesn't go here
  }.on(:failure) {
    puts "error" #=> "error"
  }

# on specific error

Result::Failure.new(:specific_error)
  .on(:success) { |v|
    puts v #=> "abc" # doesn't go here
  .on(:specific_error) {
    puts "specific error" #=> "specific error"
  }.on(:failure) {
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
  }.on(:failure) { |error, error_msg, data|
    error #=> :some_error
  }
```

### Adapters

Adapters let's you to convert other objects that describe a result of a operation to Result object.

To call adapters, use `Result.from` method with the adapter name and a block.

Out-of-the-box, Result implements only one adapter, `:exception`

#### :exception adapter

```ruby
puts Result.from(:exception) {
  JSON.parse('{"valid_json": true}')
}
#=> #<Result::Success:0x000001010ec520 @success=true, @data={"valid_json"=>true}>

puts Result.from(:exception) {
  JSON.parse('invalid JSON')
}

#=> #<Result::Failure:0x0000010211fe88 @error_msg="757: unexpected token at 'invalid JSON'", @success=false, @data=nil, @error=#<JSON::ParserError: 757: unexpected token at 'invalid JSON'>>
```

#### Custom adapters

You can add your own adapters with `add_adapter!` method.

```ruby
# Adapter :hash expects that calling the block returns a hash,
# which has a field called `success` which may be `true` or `false`
Result.add_adapter!(:hash) { |block|
  hash = block.call

  if hash[:success]
    Result::Success.new(hash)
  else
    Result::Failure.new(nil, nil, hash)
  end
}

Result.from(:hash) {
  {success: true, additional_data: true}
}
#=> #<Result::Success:0x0000010402a9e0 @success=true, @data={:success=>true, :additional_data=>true}

Result.from(:hash) {
  {success: false, additional_data: nil}
}
#=> #<Result::Failure:0x00000104018060 @error_msg=nil, @success=false, @data={:success=>false, :additional_data=>nil}, @error=nil>
```

### Shortcut methods Succ and Fail

```ruby
# for convenience, you can use shortcut methods
Succ("successful")
#=> #<Result::Success:0x007faa41872d08 @success=true, @data="successful">

# for convenience, you can use shortcut methods
Fail(:failure)
#=> #<Result::Failure:0x007faa41851540 @error_msg=nil, @success=false, @data=nil, @error=:failure>
```

