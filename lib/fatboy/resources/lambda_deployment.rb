require 'aws-sdk-cloudformation'

module Fatboy
  module Resources

    class LambdaDeployment

      attr_reader :context, :component, :environment, :coordinate, :logical_resource_id, :release_version, :lambda_alias

      def initialize(context, component, environment, coordinate, logical_resource_id, release_version, lambda_alias)
        @context = context
        @component = component
        @environment = environment
        @coordinate = coordinate
        @logical_resource_id = logical_resource_id
        @release_version = release_version
        @lambda_alias = lambda_alias
      end

      def teardown
      end

      def setup
        cf_client = Aws::CloudFormation::Client.new(
          credentials: context.wormhole.get_credentials(coordinate.account_id),
          region: coordinate.region,
        )

        stack_resources = context.cloudformation.get_resources_hash(cf_client, coordinate.name)

        context.cosmos_client.register_lambda_function(
          component,
          environment,
          stack_resources[logical_resource_id].physical_resource_id,
          coordinate.account_id,
          coordinate.region,
          lambda_alias,
        )

        v = release_version || begin
          releases = context.cosmos_client.get_lambda_releases(component)
          raise "No releases of #{component} available" if releases.empty?
          releases.first["version"]
        end

        # FIXME hard-wired to configuration_opt_out=true
        context.cosmos_client.set_lambda_configuration_opt_out(component, true)

        # FIXME should write /v1/lambdas/:name/:environment/configuration
        # here.  https://cosmos.api.bbci.co.uk/docs/rest_api_v1/endpoints.lambda_components.html#update-lambda-environment-configuration

        deployment_url = context.cosmos_client.create_lambda_release_deployment(component, environment, v)
        context.cosmos_client.wait_for_lambda_deployment(deployment_url)
      end

    end

  end
end
