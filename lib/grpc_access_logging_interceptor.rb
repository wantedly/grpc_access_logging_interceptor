require "grpc_access_logging_interceptor/version"
require "grpc_access_logging_interceptor/server_interceptor"

module GrpcAccessLoggingInterceptor
  class << self
    def new(options = {})
      ServerInterceptor.new(**options)
    end
  end
end
