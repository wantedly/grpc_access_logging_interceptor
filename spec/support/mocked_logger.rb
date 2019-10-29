module Support
  class MockedLogger
    def initialize
      @logged = []
    end

    attr_reader :logged

    # @param [Hash] data
    def log(data)
      @logged << data
    end
  end
end
