module Fatboy
  module Components
    class CliveFbdGraphPopulator

      def component
        'fbd-graph-populator'
      end

      def git_url
        "git@github.com:bbc/mss-clive-#{component}"
      end

      def add_int(context, resource_graph)
        add(
          context,
          resource_graph,
          'int',
          nil, # latest release
          'master',
        )
      end

      def add_test(context, resource_graph)
        add(
          context,
          resource_graph,
          'test',
          nil, # latest release
          'master',
        )
      end

      ############################################################
      # Nothing below here should be environment-specific
      ############################################################

      private

      def add(context, resource_graph, environment, release_version, git_revision)

        lc_environment = environment.downcase
        tc_environment = environment[0].upcase + environment[1..-1].downcase

        codebase_dir = context.scm_helper.git_clone(git_url, git_revision)
        stack_dir = "#{codebase_dir}/stacks/#{component}"

        stacks = context.spud.get_stacks(context, stack_dir, component, lc_environment)

        resources_stack = stacks['resources']
        resource_graph.register_resource(
          "cosmos.component.#{component}.environment.#{lc_environment}.stack.resources",
          resources_stack,
          [
            # Unstated dependencies:
            # CliveMonitoringResources stack
          ],
        )

        function_stack = stacks['function']
        function_stack.on_configure do |create_request|
          create_request.merge(
            parameters: {
              'LambdaHandler' => 'uk.co.bbc.mss.fbd.graphpopulator.LambdaRequestHandler',
              'LambdaMemorySize' => '512',
              'LambdaTimeout' => '300',
            },
            capabilities: [
              'CAPABILITY_IAM',
            ],
          )
        end
        resource_graph.register_resource(
          "cosmos.component.#{component}.environment.#{lc_environment}.stack.function",
          function_stack,
          [
            "cosmos.component.#{component}.environment.#{lc_environment}.stack.resources",
            # Unstated dependencies:
            # CliveMonitoringResources
            # CliveSharedResources
            # CliveSharedPrecious
            # 'java8-noop.zip' object in CliveSharedPrecious-LambdaCodeUploadBucket
          ]
        )

        lambda_deployment = Fatboy::Resources::LambdaDeployment.new(
          context,
          component,
          lc_environment,
          function_stack.coordinate,
          'LambdaFunction',
          release_version,
          nil,
        )
        resource_graph.register_resource(
          "cosmos.component.#{component}.environment.#{lc_environment}.deployment",
          lambda_deployment,
          [
            "cosmos.component.#{component}.environment.#{lc_environment}.stack.function",
            # Unstated dependencies:
            # Cosmos lambda
            # IAM role to allow Cosmos deployments
            # Precious stack
          ],
        )

      end

    end
  end
end
