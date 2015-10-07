module Result
  class Result
    attr_reader :data, :error, :error_msg

    def success?
      @success
    end

    def and_then(&block)
      if success?
        block.call(data).tap do |res|
          raise ArgumentError.new("Block must return Result") unless res.is_a?(Result)
        end
      else
        self
      end
    end
  end

  class Success < Result
    def initialize(data = nil)
      @success = true
      @data = data
    end

    def on(event_or_error, &block)
      if event_or_error == :success
        block.call
      end
    end
  end

  class Failure < Result

    RESERVED_ERRORS = [:success, :failure]

    def initialize(error = nil, error_msg = nil, data = nil)
      unless error.nil? || error.is_a?(Symbol) || error.is_a?(StandardError)
        raise ArgumentError.new("Error must be either nil, String or Exception")
      end

      if RESERVED_ERRORS.include?(error)
        raise ArgumentError.new(":#{error} is reserved and can not be used as an error")
      end

      @error_msg =
        if error.is_a?(StandardError) && error_msg.nil?
          error.message
        elsif error_msg.nil?
          nil
        else
          error_msg.to_s
        end

      @success = false
      @data = data
      @error = error
    end

    def on(event_or_error, &block)
      if event_or_error == :failure
        block.call
      elsif event_or_error == error
        block.call
      elsif event_or_error.is_a?(Class) && error.is_a?(event_or_error)
        block.call
      end
    end
  end

  def self.add_adapter!(name, &block)
    unless name.is_a?(Symbol)
      raise ArgumentError.new("Adapter name must be a symbol")
    end

    if block.nil?
      raise ArgumentError.new("No block given")
    end

    @@adapters ||= {}

    unless @@adapters[name].nil?
      raise ArgumentError.new("Adapter #{name} exists already")
    end

    @@adapters[name] = block
  end

  def self.from(adapter_name, &block)
    @@adapters ||= {}
    adapter = @@adapters[adapter_name]

    if adapter.nil?
      raise ArgumentError.new("Adapter #{adapter_name} does not exist")
    end

    if block.nil?
      raise ArgumentError.new("No block given")
    end

    adapter.call(block).tap { |adapter_result|
      unless adapter_result.is_a?(Result)
        raise ArgumentError.new("Adapter must return a Result")
      end
    }
  end
end

Result.add_adapter!(:exception) { |block|
  begin
    Result::Success.new(block.call)
  rescue StandardError => e
    Result::Failure.new(e, e.message)
  end
}
