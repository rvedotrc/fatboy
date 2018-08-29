require 'json'
require 'weakref'

module Fatboy
  module Cosmos

    module LiveInstance

      CLOUDFORMATION_EVENTS_TOPIC = {
        'eu-west-1' => 'arn:aws:sns:eu-west-1:240129357028:live-cosmos-resources-CloudFormationEventsTopic-1Q43OSTO5242I',
      }

      V1_API_ENDPOINT = 'https://cosmos.api.bbci.co.uk/v1'

    end

    class Client

      def initialize(context, forge_helper, cosmos_instance)
        @context = WeakRef.new(context)
        @forge_helper = forge_helper
        @cosmos_instance = cosmos_instance
      end

      def register_lambda_function(component, environment,
                                   function_name, account_id, region,
                                   lambda_alias)
        c = {
          name: function_name,
          aws_account: account_id,
          region: region,
        }
        c[:alias] = lambda_alias if lambda_alias

        @forge_helper.connect("#{@cosmos_instance::V1_API_ENDPOINT}/lambdas/#{component}/#{environment}/function").put(
          c.to_json,
          {
            content_type: :json,
            accept: :json,
          },
        )
      end

      def set_lambda_configuration_opt_out(component, value)
        @forge_helper.connect("#{@cosmos_instance::V1_API_ENDPOINT}/lambdas/#{component}/configuration_opt_out").put(
          {
            value: value,
          }.to_json,
          {
            content_type: :json,
            accept: :json,
          },
        )
      end

      def get_lambda_releases(component)
        releases_json = @forge_helper.connect("#{@cosmos_instance::V1_API_ENDPOINT}/lambdas/#{component}/releases").get.body
        JSON.parse(releases_json)["releases"]
      end

      def create_lambda_release_deployment(component, environment, release_version)
        response = ForgeHelper.new.connect("#{@cosmos_instance::V1_API_ENDPOINT}/lambdas/#{component}/#{environment}/deployments").post(
          {
            release_version: release_version,
          }.to_json,
          {
            content_type: :json,
            accept: :json,
          },
        )

        deployment_url = JSON.parse(response.body)["ref"]
      end

      def wait_for_lambda_deployment(deployment_url)
        # Wait for deployment to complete
        # Polling, for now
        begin
          while true
            deployment = JSON.parse(@forge_helper.connect(deployment_url).get.body)
            @context.logger.puts "cosmos lambda deployment #{deployment["component"]["name"]}" \
              + " release #{deployment["release"]["version"]}" \
              + " to #{deployment["environment"]["name"]}" \
              + " : #{deployment["status"]}"

            case deployment["status"]
            when "done"
              break
            when "failed"
              raise "Deployment failed"
            else
              sleep 5
            end
          end
        end
      end

    end

  end
end
