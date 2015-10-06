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
      res = Result::Failure.new(:failure).and_then { |v| Result::Success.new(v + 1) }
      expect(res.success?).to eq(false)
    end
  end

  describe "on_success" do
    it "runs only on success" do
      run_success = false
      run_error = false
      Result::Success.new(1).on_success { run_success = true }
      Result::Failure.new().on_success { run_error = true }
      expect(run_success).to eq(true)
      expect(run_error).to eq(false)
    end
  end

  describe "on_failure" do
    it "runs only on failure" do
      run_success = false
      run_error = false
      Result::Success.new(1).on_failure { run_success = true }
      Result::Failure.new().on_failure { run_error = true }
      expect(run_success).to eq(false)
      expect(run_error).to eq(true)
    end
  end
end
