require "json"
require "logger"

module GrpcAccessLoggingInterceptor
  class DefaultLogger
    # @param [#info] logger
    def initialize(logger: Logger.new($stdout))
      @logger = logger
    end

    # @param [Hash] hash
    def log(data)
      @logger.info(data.to_json)
    end
  end
end
