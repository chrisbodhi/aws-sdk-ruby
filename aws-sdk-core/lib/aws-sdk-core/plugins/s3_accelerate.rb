module Aws
  module Plugins

    # Provides support for using `Aws::S3::Client` with Amazon S3 Transfer
    # Acceleration.
    #
    # Go here for more information about transfer acceleration:
    # [http://docs.aws.amazon.com/AmazonS3/latest/dev/transfer-acceleration.html](http://docs.aws.amazon.com/AmazonS3/latest/dev/transfer-acceleration.html)
    #
    # @seahorse.client.option [Boolean] :use_accelerate_endpoint (false)
    #   When set to `true`, accelerated bucket endpoints will be used
    #   for all object operations. You must first enable
    #   accelerate for each bucket. [Go here for more information](http://docs.aws.amazon.com/AmazonS3/latest/dev/transfer-acceleration.html).
    #
    class S3Accelerate < Seahorse::Client::Plugin

      option(:use_accelerate_endpoint, false)

      def add_handlers(handlers, config)
        operations = config.api.operation_names - [
          :create_bucket, :list_buckets, :delete_bucket,
        ]
        handlers.add(OptionHandler, step: :initialize, operations: operations)
        handlers.add(AccelerateHandler, step: :build, priority: 0, operations: operations)
      end

      # @api private
      class OptionHandler < Seahorse::Client::Handler
        def call(context)
          accelerate = context.params.delete(:use_accelerate_endpoint)
          accelerate = context.config.use_accelerate_endpoint if accelerate.nil?
          context[:use_accelerate_endpoint] = accelerate
          @handler.call(context)
        end
      end

      # @api private
      class AccelerateHandler < Seahorse::Client::Handler

        def call(context)
          use_accelerate_endpoint(context) if context[:use_accelerate_endpoint]
          @handler.call(context)
        end

        private

        def use_accelerate_endpoint(context)
          bucket_name = context.params[:bucket]
          validate_bucket_name!(bucket_name)
          endpoint = URI.parse(context.http_request.endpoint.to_s)
          endpoint.scheme = 'https'
          endpoint.port = 443
          endpoint.host = "#{bucket_name}.s3-accelerate.amazonaws.com"
          context.http_request.endpoint = endpoint.to_s
        end

        def validate_bucket_name!(bucket_name)
          unless S3BucketDns.dns_compatible?(bucket_name, ssl = true)
            msg = "unable to use `accelerate: true` on buckets with "
            msg << "non-DNS compatible names"
            raise ArgumentError, msg
          end
          if bucket_name.include?('.')
            msg = "unable to use `accelerate: true` on buckets with dots"
            msg << "in their name: #{bucket_name.inspect}"
            raise ArgumentError, msg
          end
        end

      end
    end
  end
end
