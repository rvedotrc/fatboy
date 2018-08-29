require 'aws-sdk-cloudformation'

module Fatboy
  module Resources

    class SpudStack

      attr_reader :context, :stack_dir, :environment, :stack_type, :coordinate

      def initialize(context, stack_dir, environment, stack_type, coordinate)
        @context = context
        @stack_dir = stack_dir
        @environment = environment
        @stack_type = stack_type
        @coordinate = coordinate
      end

      def on_configure(&callback)
        @callback = callback
      end

      def teardown
        cf_client = Aws::CloudFormation::Client.new(
          credentials: context.wormhole.get_credentials(coordinate.account_id),
          region: coordinate.region,
        )

        @context.cloudformation.delete_if_exists(cf_client, coordinate.name)
      end

      def setup
        cf_client = Aws::CloudFormation::Client.new(
          credentials: context.wormhole.get_credentials(coordinate.account_id),
          region: coordinate.region,
        )

        template_body = context.spud.generate_template(stack_dir, environment, stack_type)

        request = {
          stack_name: coordinate.name,
          template_body: template_body,
          notification_arns: [
            context.cosmos_instance::CLOUDFORMATION_EVENTS_TOPIC[coordinate.region],
          ],
        }

        if @callback
          request = @callback.call(request)
        end

        unless request.kind_of? Hash
          raise "on_configure returned #{request.inspect}, not a hash"
        end

        if request[:parameters].kind_of? Hash
          request[:parameters] = context.cloudformation.cf_params(request[:parameters])
        end

        stack_id = cf_client.create_stack(request).stack_id

        context.cloudformation.wait_for_stack_status(cf_client, stack_id, 'CREATE_COMPLETE')
      end

    end

  end
end
