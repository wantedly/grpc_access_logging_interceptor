require "google/protobuf/empty_pb"
require "google/protobuf/wrappers_pb"
require "timecop"
require "support/mocked_logger"
require "support/value_filter"

describe GrpcAccessLoggingInterceptor do
  describe "#request_response" do
    let(:interceptor) {
      GrpcAccessLoggingInterceptor.new(
        logger: mocked_logger,
        **options
      )
    }
    let(:mocked_logger) { Support::MockedLogger.new }
    let(:request) { Google::Protobuf::StringValue.new(value: "World") }
    let(:call) { double(:call, peer: "ipv4:127.0.0.1:63634", metadata: metadata) }
    let(:metadata) {
      { "user-agent" => "grpc-node/1.19.0 grpc-c/7.0.0 (linux; chttp2; gold)" }
    }
    let(:method) { service_class.new.method(:hello_rpc) }
    let(:service_class) {
      Class.new(rpc_class) do
        def self.name
          "TestModule::TestService"
        end

        def hello_rpc(req, call)
          # Do nothing
        end
      end
    }
    let(:rpc_class) {
      Class.new do
        include GRPC::GenericService

        self.marshal_class_method = :encode
        self.unmarshal_class_method = :decode
        self.service_name = 'test.Test'

        rpc :HelloRpc, Google::Protobuf::StringValue, Google::Protobuf::Empty
      end
    }

    context "when no exception occurs" do
      let(:options) { {} }

      it "logs an access log" do
        Timecop.freeze(Time.new(2019, 3, 15, 0, 0)) do
          interceptor.request_response(request: request, call: call, method: method) { }
        end
        expect(mocked_logger.logged).to eq [
          {
            accessed_at:      "2019-03-15 00:00:00.000000",
            grpc_metadata:    "{\"user-agent\":\"grpc-node/1.19.0 grpc-c/7.0.0 (linux; chttp2; gold)\"}",
            grpc_method:      "/test.Test/HelloRpc",
            grpc_status_code: 0,
            params:           "{\"value\":\"World\"}",
            remote_addr:      "127.0.0.1",
            response_time_ms: 0.0,
            user_agent:       "grpc-node/1.19.0 grpc-c/7.0.0 (linux; chttp2; gold)",
          }
        ]
      end
    end

    context "when an exception occurs in yield" do
      let(:options) { {} }

      it "logs an access log with failure status code" do
        expect {
          Timecop.freeze(Time.new(2019, 3, 15, 0, 0)) do
            interceptor.request_response(request: request, call: call, method: method) do
              raise GRPC::NotFound.new("Resource A is not found")
            end
          end
        }.to raise_error(GRPC::NotFound)

        expect(mocked_logger.logged).to eq [
          {
            accessed_at:      "2019-03-15 00:00:00.000000",
            grpc_metadata:    "{\"user-agent\":\"grpc-node/1.19.0 grpc-c/7.0.0 (linux; chttp2; gold)\"}",
            grpc_method:      "/test.Test/HelloRpc",
            grpc_status_code: 5,  # GRPC::NotFound
            params:           "{\"value\":\"World\"}",
            remote_addr:      "127.0.0.1",
            response_time_ms: 0.0,
            user_agent:       "grpc-node/1.19.0 grpc-c/7.0.0 (linux; chttp2; gold)",
          }
        ]
      end
    end

    context "when an exception occurs when setting information to data" do
      let(:options) { {} }

      before do
        allow(interceptor).to receive(:remote_addr).and_raise("Unknown Error")
      end

      it "logs an access log with failure status code" do
        expect {
          Timecop.freeze(Time.new(2019, 3, 15, 0, 0)) do
            interceptor.request_response(request: request, call: call, method: method) {}
          end
        }.to raise_error("Unknown Error")

        expect(mocked_logger.logged).to eq [
          {
            grpc_status_code: 2,  # GRPC::Unknown
            response_time_ms: 0.0
          }
        ]
      end
    end

    context "when params_filter is specified" do
      let(:options) {
        {
          params_filter: Support::ValueFilter.new
        }
      }

      it "logs an access log with filtered params" do
        Timecop.freeze(Time.new(2019, 3, 15, 0, 0)) do
          interceptor.request_response(request: request, call: call, method: method) {}
        end

        expect(mocked_logger.logged).to eq [
          {
            accessed_at:      "2019-03-15 00:00:00.000000",
            grpc_metadata:    "{\"user-agent\":\"grpc-node/1.19.0 grpc-c/7.0.0 (linux; chttp2; gold)\"}",
            grpc_method:      "/test.Test/HelloRpc",
            grpc_status_code: 0,
            params:           "{\"value\":\"[FILTERED]\"}",
            remote_addr:      "127.0.0.1",
            response_time_ms: 0.0,
            user_agent:       "grpc-node/1.19.0 grpc-c/7.0.0 (linux; chttp2; gold)",
          }
        ]
      end
    end

    context "when a custom_data_provider is specified" do
      context "when custom_data_provider is proc" do
        let(:options) {
          {
            custom_data_provider: -> (request, call, method) {
              {
                custom_data_provider: true,
                request:              request,
                call:                 call,
                method:               method,
              }
            }
          }
        }

        it "logs an access log with custom data" do
          Timecop.freeze(Time.new(2019, 3, 15, 0, 0)) do
            interceptor.request_response(request: request, call: call, method: method) {}
          end

          expect(mocked_logger.logged).to eq [
            {
              accessed_at:          "2019-03-15 00:00:00.000000",
              grpc_metadata:        "{\"user-agent\":\"grpc-node/1.19.0 grpc-c/7.0.0 (linux; chttp2; gold)\"}",
              grpc_method:          "/test.Test/HelloRpc",
              grpc_status_code:     0,
              params:               "{\"value\":\"World\"}",
              remote_addr:          "127.0.0.1",
              response_time_ms:     0.0,
              user_agent:           "grpc-node/1.19.0 grpc-c/7.0.0 (linux; chttp2; gold)",
              custom_data_provider: true,
              request:              request,
              call:                 call,
              method:               method,
            }
          ]
        end
      end

      context "when custom_data_provider is an object with #execute method" do
        let(:options) {
          {
            custom_data_provider: custom_data_provider_class.new
          }
        }
        let(:custom_data_provider_class) {
          Class.new do
            def execute(request, call, method)
              {
                custom_data_provider: true,
                request:              request,
                call:                 call,
                method:               method,
              }
            end
          end
        }

        it "logs an access log with custom data" do
          Timecop.freeze(Time.new(2019, 3, 15, 0, 0)) do
            interceptor.request_response(request: request, call: call, method: method) {}
          end

          expect(mocked_logger.logged).to eq [
            {
              accessed_at:          "2019-03-15 00:00:00.000000",
              grpc_metadata:        "{\"user-agent\":\"grpc-node/1.19.0 grpc-c/7.0.0 (linux; chttp2; gold)\"}",
              grpc_method:          "/test.Test/HelloRpc",
              grpc_status_code:     0,
              params:               "{\"value\":\"World\"}",
              remote_addr:          "127.0.0.1",
              response_time_ms:     0.0,
              user_agent:           "grpc-node/1.19.0 grpc-c/7.0.0 (linux; chttp2; gold)",
              custom_data_provider: true,
              request:              request,
              call:                 call,
              method:               method,
            }
          ]
        end
      end
    end
  end
end
