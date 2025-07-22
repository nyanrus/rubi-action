# typed: strict
# frozen_string_literal: true

module Result
  class Success
    extend T::Sig
    extend T::Generic

    Value = type_member

    sig { params(value: Value).void }
    def initialize(value)
      @value = value
    end

    sig { returns(Value) }
    attr_reader :value

    sig { returns(T::Boolean) }
    def success?
      true
    end

    sig { returns(T::Boolean) }
    def failure?
      false
    end
  end

  class Failure
    extend T::Sig
    extend T::Generic

    Error = type_member

    sig { params(error: Error).void }
    def initialize(error)
      @error = error
    end

    sig { returns(Error) }
    attr_reader :error

    sig { returns(T::Boolean) }
    def success?
      false
    end

    sig { returns(T::Boolean) }
    def failure?
      true
    end
  end
end