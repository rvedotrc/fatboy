module Fatboy
  module CloudFormation

    class Coordinate
      attr_reader :region, :account_id, :name
      def initialize(region, account_id, name)
        @region = region
        @account_id = account_id
        @name = name
      end
    end

    class JunkDrawer

      def delete_if_exists(cf_client, stack_name_or_id)
        stack_id = begin
          r = cf_client.describe_stacks(
            stack_name: stack_name_or_id,
          )
          r.stacks[0].stack_id
        rescue Aws::CloudFormation::Errors::Throttling
          sleep 5
          retry
        rescue Aws::CloudFormation::Errors::ValidationError
          nil
        end

        stack_id or return

        cf_client.delete_stack(
          stack_name: stack_id,
        )

        wait_for_stack_status(cf_client, stack_id, 'DELETE_COMPLETE')
      end

      def wait_for_stack_status(cf_client, stack_name_or_id, desired_status)
        # Simple poll-based for now
        description = nil
        while true
          description = begin
            cf_client.describe_stacks(
              stack_name: stack_name_or_id,
            )
          rescue Aws::CloudFormation::Errors::Throttling => e
            puts "Error describing stack #{stack_name_or_id}: #{e}"
            sleep 5
            retry
          end
          puts description.stacks[0].stack_status + " " + description.stacks[0].stack_name

          case description.stacks[0].stack_status
          when /IN_PROGRESS/
            sleep 5
            next
          when desired_status
            break
          else
            raise 'Stack creation/deletion/update failed'
          end
        end
      end

      def cf_params(hash)
        hash.entries.map do |k, v|
          { parameter_key: k, parameter_value: v }
        end
      end

      def get_resources_hash(cf_client, stack_name_or_id)
        # FIXME: pagination
        cf_client.list_stack_resources(
          stack_name: stack_name_or_id,
        ).stack_resource_summaries.map {|s| [ s.logical_resource_id, s ] }.to_h
      end

    end
    
  end
end
