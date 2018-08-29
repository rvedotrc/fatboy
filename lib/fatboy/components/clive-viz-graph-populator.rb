module Fatboy
  module Components
    class CliveVizGraphPopulator

      def component
        'mss-clive-viz-graph-populator'
      end

      def git_url
        'git@github.com:bbc/mss-viz-graph-populator'
      end

      def add_int(context, resource_graph)
        add(
          context,
          resource_graph,
          'int',
          nil, # latest
          'master',
        )
      end

      def add_test(context, resource_graph)
        add(
          context,
          resource_graph,
          'test',
          nil, # latest
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
        # FIXME: irregular
        stack_dir = "#{codebase_dir}/stacks/mss-viz-graph-populator"

        # FIXME: irregular
        stacks = context.spud.get_stacks(context, stack_dir, 'mss-viz-graph-populator', lc_environment)

        resources_stack = stacks['resources']
        resource_graph.register_resource(
          "cosmos.component.#{component}.environment.#{lc_environment}.stack.resources",
          resources_stack,
          [
            "cosmos.component.mss-clive-viz-delta-ingester-lambda.environment.#{lc_environment}.stack.resources",
            # Unstated dependencies:
          ],
        )

        component_stack = stacks['component']
        component_stack.on_configure do |create_request|
          create_request.merge(
            parameters: {
              'ComponentName' => 'FIXME, unused parameter',
              'LambdaMemorySize' => '512',
            },
            capabilities: [
              'CAPABILITY_IAM',
            ],
          )
        end
        resource_graph.register_resource(
          "cosmos.component.#{component}.environment.#{lc_environment}.stack.component",
          component_stack,
          [
            "cosmos.component.#{component}.environment.#{lc_environment}.stack.resources",
            "cosmos.component.mss-clive-viz-delta-ingester-lambda.environment.#{lc_environment}.stack.resources",
            # Unstated dependencies:
            # core-infrastructure
            # CliveSharedResources
            # CliveSharedPrecious
            # CliveMonitoringResources
            # CliveAuditHistoryResources (should be removed)
            # 'java8-noop.zip' object in CliveSharedPrecious-LambdaCodeUploadBucket
          ]
        )

        lambda_deployment = Fatboy::Resources::LambdaDeployment.new(
          context,
          component,
          lc_environment,
          component_stack.coordinate,
          'VizGraphPopulatorFunction',
          release_version,
          lc_environment,
        )
        resource_graph.register_resource(
          "cosmos.component.#{component}.environment.#{lc_environment}.deployment",
          lambda_deployment,
          [
            "cosmos.component.#{component}.environment.#{lc_environment}.stack.component",
            # Unstated dependencies:
            # Cosmos lambda
            # IAM role to allow Cosmos deployments
          ],
        )

      end

    end
  end
end
