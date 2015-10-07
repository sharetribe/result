require './lib/result'

RSpec.describe Result do
  describe Result::Success do
    it "creates a Success" do
      res = Result::Success.new()
      expect(res.success?).to eq(true)
      expect(res.data).to eq(nil)
    end

    it "creates a Success with data" do
      res = Result::Success.new({data: true})
      expect(res.success?).to eq(true)
      expect(res.data).to eq({data: true})
    end
  end
  describe Result::Failure do
    describe "error" do
      it "creates a Failure" do
        expect(Result::Failure.new().success?).to eq(false)
      end

      it "creates a Failure without an error" do
        expect(Result::Failure.new().error).to eq(nil)
      end

      it "creates a Failure with a symbol error" do
        expect(Result::Failure.new(:error).error).to eq(:error)
      end

      it "creates a Failure with a expection error" do
        expect(Result::Failure.new(ArgumentError.new()).error).to be_a(ArgumentError)
      end

      it "fails if error is not nil, symbol or expection" do
        expect { Result::Failure.new("string") }.to raise_error(ArgumentError)
      end
    end
    describe "error_msg" do
      it "creates a Failure with error_msg" do
        expect(Result::Failure.new(nil, "Error message").error_msg).to eq("Error message")
      end

      it "converts the message to string" do
        expect(Result::Failure.new(nil, nil).error_msg).to eq(nil)
        expect(Result::Failure.new(nil, true).error_msg).to eq("true")
      end

      it "takes the message from the exception" do
        expect(Result::Failure.new(ArgumentError.new("Error message")).error_msg).to eq("Error message")
      end

      it "overriedes the Exception message if error_msg is given" do
        expect(Result::Failure.new(ArgumentError.new("Error message"), "Another message").error_msg)
          .to eq("Another message")
      end
    end
    describe "data" do
      it "creates a Failure with data" do
        expect(Result::Failure.new(nil, nil, {data: true}).data)
          .to eq({data: true})
      end
    end
  end

  describe "adapters" do

    describe "custom adapters" do
      it "throws if adapter name is not symbol" do
        expect {
          Result.add_adapter!("not a symbol") { true }
        }.to raise_error(ArgumentError)
      end

      it "throws if block is not given" do
        expect {
          Result.add_adapter!(:no_block_given)
        }.to raise_error(ArgumentError)
      end

      it "throws if the name is already in use" do
        expect { Result.add_adapter!(:name_in_use) { } }.not_to raise_error
        expect { Result.add_adapter!(:name_in_use) { } }.to raise_error(ArgumentError, "Adapter name_in_use exists already")
      end

      it "throws if adapter can not be found" do
        expect { Result.from(:adapter_does_not_exist) { } }
          .to raise_error(ArgumentError, "Adapter adapter_does_not_exist does not exist")
      end

      it "throws if no block is given to the #from method" do
        expect { Result.from(:exception) }
          .to raise_error(ArgumentError, "No block given")
      end

      it "throws if adapter doesn't return a Result" do
        Result.add_adapter!(:broken_adapter) { |block| true }

        expect { Result.from(:broken_adapter) { true } }
          .to raise_error(ArgumentError, "Adapter must return a Result")
      end

      it "adds and uses a custom :boolean adapter" do
        Result.add_adapter!(:boolean) { |block|
          if block.call
            Result::Success.new
          else
            Result::Failure.new
          end
        }

        expect(Result.from(:boolean) { true }.success?).to eq(true)
        expect(Result.from(:boolean) { nil }.success?).to eq(false)
      end
    end

    describe "from(:exception)" do

      def operation(result)
        if result
          {data: true}
        else
          raise ArgumentError.new("Failed")
        end
      end

      it "tries to do the operation and returns Success" do
        res = Result.from(:exception) { operation(true) }
        expect(res.success?).to eq(true)
        expect(res.data).to eq({data: true})
      end

      it "tries to do the operation and returns Failure" do
        res = Result.from(:exception) { operation(false) }
        expect(res.success?).to eq(false)
        expect(res.error).to be_a(ArgumentError)
        expect(res.error_msg).to eq("Failed")
      end
    end
  end

  describe "and_then" do
    it "run if Success" do
      res = Result::Success.new(1).and_then { |v| Result::Success.new(v + 1) }
      expect(res.success?).to eq(true)
      expect(res.data).to eq(2)
    end

    it "does not run if Failure" do
      res = Result::Failure.new(:error).and_then { |v| Result::Success.new(v + 1) }
      expect(res.success?).to eq(false)
    end

    it "throws if block doesn't return Result" do
      expect { Result::Success.new(1).and_then { |v| v } }
        .to raise_error(ArgumentError, "Block must return Result")
    end
  end

  describe "#on" do
    it "reserves error names :success and :failure" do
      expect { Result::Failure.new(:success) }
        .to raise_error(ArgumentError, ":success is reserved and can not be used as an error")

      expect { Result::Failure.new(:failure) }
        .to raise_error(ArgumentError, ":failure is reserved and can not be used as an error")
    end

    it "executes on(:success) for Success result" do
      on_success = false
      on_failure = false

      Result::Success.new().on(:success) { on_success = true }
      Result::Success.new().on(:failure) { on_failure = true }

      expect(on_success).to eq(true)
      expect(on_failure).to eq(false)
    end

    it "passes data to the success handler" do
      actual_data = nil
      Result::Success.new(my_data: true).on(:success) { |result_data|
        actual_data = result_data
      }
      expect(actual_data).to eq(my_data: true)
    end

    it "executes on(:failure) for Failure result" do
      on_success = false
      on_failure = false

      Result::Failure.new().on(:success) { on_success = true }
      Result::Failure.new().on(:failure) { on_failure = true }

      expect(on_success).to eq(false)
      expect(on_failure).to eq(true)
    end

    it "passes error, error_msg and data to the failure handler" do
      actual_error = nil
      actual_error_msg = nil
      actual_data = nil

      Result::Failure.new(:my_error, "My error message", my_data: true)
        .on(:failure) { |error, error_msg, data|
        actual_error = error
        actual_error_msg = error_msg
        actual_data = data
      }
      expect(actual_error).to eq(:my_error)
      expect(actual_error_msg).to eq("My error message")
      expect(actual_data).to eq(my_data: true)
    end

    it "executes only for a specific error" do
      on_failure = false
      on_error1 = false
      on_error2 = false

      res = Result::Failure.new(:error1)

      res.on(:failure) { on_failure = true }
      res.on(:error1) { on_error1 = true }
      res.on(:error2) { on_error2 = true }

      expect(on_failure).to eq(true)
      expect(on_error1).to eq(true)
      expect(on_error2).to eq(false)
    end

    it "executes only for a specific exception" do
      on_failure = false
      on_zero_error = false
      on_argument_error = false

      exception = ZeroDivisionError.new("You can't devide by zero")
      res = Result::Failure.new(exception)

      res.on(:failure) { on_failure = true }
      res.on(ZeroDivisionError) { on_zero_error = true }
      res.on(ArgumentError) { on_argument_error = true }

      expect(on_failure).to eq(true)
      expect(on_zero_error).to eq(true)
      expect(on_argument_error).to eq(false)
    end
  end
end
