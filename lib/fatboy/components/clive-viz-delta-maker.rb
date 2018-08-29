module Fatboy
  module Components
    class CliveVizDeltaMaker

      def component
        'mss-clive-viz-delta-maker-lambda'
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
            'CSVBucketUploaderAllowedPrincipal' => 'arn:aws:iam::115755622757:user/mss-csv-uploader',
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
            'CSVBucketUploaderAllowedPrincipal' => 'arn:aws:iam::115755622757:user/mss-csv-uploader',
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

        # TODO? resource stack includes a bucket, so could have a resource
        # depending on 'resources', which empties the bucket on teardown

        component_stack = stacks['component']
        component_stack.on_configure do |create_request|
          create_request.merge(
            parameters: {
              'ComponentName' => 'FIXME, unused parameter',
              'LambdaMemorySize' => '768',
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
            # Unstated dependencies:
            # CliveSharedResources
            # CliveSharedPrecious
            # 'java8-noop.zip' object in CliveSharedPrecious-LambdaCodeUploadBucket
          ]
        )

        lambda_deployment = Fatboy::Resources::LambdaDeployment.new(
          context,
          component,
          lc_environment,
          component_stack.coordinate,
          'VizDeltaMakerFunction',
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
