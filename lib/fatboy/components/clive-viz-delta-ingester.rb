module Fatboy
  module Components
    class CliveVizDeltaIngester

      def component
        'mss-clive-viz-delta-ingester-lambda'
      end

      def git_url
        "git@github.com:bbc/#{component}"
      end

      def add_int(context, resource_graph)
        add(
          context,
          resource_graph,
          'int',
          {
              'DaContentsDynamoReadCapacity' => '10',
              'DaContentsDynamoWriteCapacity' => '10',
              'FbdAccountExternalId' => '2d5a9358-fb93-11e7-a0d6-3fe45fae61a9',
              'FbdAccountId' => '537989602554',
          },
          nil, # latest
          'master',
        )
      end

      def add_test(context, resource_graph)
        add(
          context,
          resource_graph,
          'test',
          {
              'DaContentsDynamoReadCapacity' => '10',
              'DaContentsDynamoWriteCapacity' => '10',
              'FbdAccountExternalId' => '2ad31b9e-fb95-11e7-911b-478caed86033',
              'FbdAccountId' => '537989602554',
          },
          nil, # latest
          'master',
        )
      end

      ############################################################
      # Nothing below here should be environment-specific
      ############################################################

      private

      def add(context, resource_graph, environment, resource_parameters, release_version, git_revision)

        lc_environment = environment.downcase
        tc_environment = environment[0].upcase + environment[1..-1].downcase

        codebase_dir = context.scm_helper.git_clone(git_url, git_revision)
        stack_dir = "#{codebase_dir}/stacks/#{component}"

        stacks = context.spud.get_stacks(context, stack_dir, component, lc_environment)

        resources_stack = stacks['resources']
        resources_stack.on_configure do |create_request|
          create_request.merge(
            parameters: resource_parameters,
            capabilities: [
              'CAPABILITY_IAM',
            ],
          )
        end
        resource_graph.register_resource(
          "cosmos.component.#{component}.environment.#{lc_environment}.stack.resources",
          resources_stack,
          [
            # Unstated dependencies:
            # CliveMonitoringResources
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
            "cosmos.component.mss-clive-viz-delta-maker-lambda.environment.#{lc_environment}.stack.resources",
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
          'VizDeltaIngesterFunction',
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
