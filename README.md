# GrpcAccessLoggingInterceptor
An interceptor for access logging with gRPC.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'grpc_access_logging_interceptor'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install grpc_access_logging_interceptor

## Usage
Please set a `GrpcAccessLoggingInterceptor` as an interceptor of your gRPC application.

```ruby
require 'grpc'
require 'grpc_access_logging_interceptor'

server = GRPC::RpcServer.new(
  interceptors: [
    GrpcAccessLoggingInterceptor.new,
  ]
)
server.handle(MyHandler.new)
server.run_till_terminated_or_interrupted(['SIGINT'])
```

With this setting, the following access logs will be printed.

```console
I, [2019-03-15T00:00:00.000000 #30034]  INFO -- : {"remote_addr":"127.0.0.1","accessed_at":"2019-03-15 00:00:00.000000","params":"{\"value\":\"World\"}","user_agent":"grpc-node/1.19.0 grpc-c/7.0.0 (linux; chttp2; gold)","grpc_method":"/test.Test/HelloRpc","grpc_metadata":"{\"user-agent\":\"grpc-node/1.19.0 grpc-c/7.0.0 (linux; chttp2; gold)\"}","grpc_status_code":0,"response_time_ms":0.0}
```

### The information in the access log

You can get information for the following fields.

| Field Name | Meaning |
| -- | -- |
| accessed_at | The time that the request was received  |
| grpc_metadata | [gRPC's metadata](https://grpc.io/docs/guides/concepts/#metadata) |
| grpc_method | A path string (cf. [gRPC over HTTP2](https://github.com/grpc/grpc/blob/master/doc/PROTOCOL-HTTP2.md)) |
| grpc_status_code | [Status codes in gRPC](https://github.com/grpc/grpc/blob/master/doc/statuscodes.md) |
| params | Request parameter in JSON |
| remote_addr |  IP address of a client (e.g. `"127.0.0.1"`) |
| response_time_ms | Response time (ms) |
| user_agent | User agent (e.g. `"grpc_health_probe grpc-go/1.17.0"`) |

### Custom Logger

You can use your custom logger.

```ruby
server = GRPC::RpcServer.new(
  interceptors: [
    GrpcAccessLoggingInterceptor.new(logger: YourCustomLogger.new),
  ]
)
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bundle exec rspec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/wantedly/grpc_access_logging_interceptor.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
