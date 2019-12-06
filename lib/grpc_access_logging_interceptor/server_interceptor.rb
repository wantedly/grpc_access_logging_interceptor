require "base64"
require "grpc"
require "grpc_access_logging_interceptor/default_logger"

module GrpcAccessLoggingInterceptor
  class ServerInterceptor < GRPC::ServerInterceptor
    USER_AGENT_KEY = "user-agent"

    # @param [#log] logger
    # @param [#filter, nil] params_filter
    # @param [#call, #execute, nil] custom_data_provider
    def initialize(logger: DefaultLogger.new, params_filter: nil, custom_data_provider: nil)
      @logger               = logger
      @params_filter        = params_filter
      @custom_data_provider = custom_data_provider
    end

    ##
    # Intercept a unary request response call.
    #
    # @param [Object] request
    # @param [GRPC::ActiveCall::SingleReqView] call
    # @param [Method] method
    #
    def request_response(request:, call:, method:)
      data = {} # Initialize at first to avoid nil

      accessed_at = Time.now

      data.merge!({
        remote_addr:   remote_addr(call.peer),
        accessed_at:   accessed_at.utc.strftime('%Y-%m-%d %H:%M:%S.%6N'),
        params:        filter(request.to_h).to_json,
        user_agent:    call.metadata[USER_AGENT_KEY],
        grpc_method:   grpc_method(method),
        grpc_metadata: jsonize(call.metadata),
      })
      data.merge!(custom_data(request: request, call: call, method: method))

      yield

      data[:grpc_status_code] = 0  # OK
    rescue StandardError => e
      data[:grpc_status_code] = grpc_status_code(e)
      raise e
    ensure
      data[:response_time_ms] = response_time_ms(accessed_at)
      log(data)
    end

    # NOTE: For now, we don't support server_streamer, client_streamer and bidi_streamer

  private

    # @param [Object] peer
    # @return [String, nil]
    def remote_addr(peer)
      # Usually peer is a string such as "ipv4:127.0.0.1:63634"
      if peer.is_a?(String) && peer[0..4] == 'ipv4:'
        peer.split(':')[1]
      else
        nil
      end
    end

    # @param [Method] method
    # @return [String]
    def grpc_method(method)
      # We use path, which is represented as "/" Service-Name "/" {method name}
      # e.g. /google.pubsub.v2.PublisherService/CreateTopic.
      # cf. https://github.com/grpc/grpc/blob/v1.24.0/doc/PROTOCOL-HTTP2.md
      "/#{method.owner.service_name}/#{camelize(method.name.to_s)}"
    end

    # @param [Hash] metadata
    # @return [String]
    def jsonize(metadata)
      h = {}
      metadata.each do |k, v|
        if v.is_a?(String) && v.encoding == Encoding::ASCII_8BIT
          # If the value is binary, encode with Base64
          h[k] = Base64.strict_encode64(v)
        else
          h[k] = v
        end
      end
      h.to_json
    end

    # @param [String] term
    # @return [String]
    def camelize(term)
      term.split("_").map(&:capitalize).join
    end

    # @param [Hash] params
    # @return [Hash]
    def filter(params)
      if @params_filter
        @params_filter.filter(params)
      else
        params
      end
    end

    # @param [Object] request
    # @param [GRPC::ActiveCall::SingleReqView] call
    # @param [Method] method
    # @return [Hash]
    def custom_data(request:, call:, method:)
      if @custom_data_provider
        if @custom_data_provider.respond_to?(:call)
          @custom_data_provider.call(request, call, method)
        elsif @custom_data_provider.respond_to?(:execute)
          @custom_data_provider.execute(request, call, method)
        else
          raise "custom_data_provider must support #execute or #call!"
        end
      else
        {}
      end
    end

    # @param [StandardError] e
    # @return [Integer] represents the grpc status code
    def grpc_status_code(e)
      case e
      when GRPC::BadStatus
        e.code
      else
        2  # GRPC::Unknown
      end
    end

    # @param [Time] from
    # @return [Integer]
    def response_time_ms(from)
      (Time.now - from) * 1000
    end

    # @param [Hash] data
    def log(data)
      @logger.log(data)
    end
  end
end
