require 'bundler'
require 'tempfile'
require 'shellwords'
require 'ostruct'
require 'json'

require 'fatboy/resources/spud_stack'

module Fatboy
  class Spud

    def initialize
      @clean_modav_spud_mutexes = {}
      @hash_mutex = Mutex.new
    end

    def get_stacks(context, stack_dir, component, environment)
      stacks = JSON.parse(IO.read "#{stack_dir}/stack_names.json")[component][environment]

      stacks.entries.select do |k, v|
        not v["skip"]
      end.map do |k, v|
        coord = Fatboy::CloudFormation::Coordinate.new(
          v['region'],
          context.wormhole.resolve(v['account_alias']),
          v['stack_name'],
        )
        [ k, Fatboy::Resources::SpudStack.new(context, stack_dir, environment, k, coord) ]
      end.to_h
    end

    def generate_template(stack_dir, environment, stack_type)
      # FIXME can't do concurrent clean-modav-spud running in the same
      # directory.  There is a better way of doing this.

      m = @hash_mutex.synchronize do
        @clean_modav_spud_mutexes[stack_dir] ||= Mutex.new
      end

      m.synchronize do
        generate_template_unsafe(stack_dir, environment, stack_type)
      end
    end

    def generate_template_unsafe(stack_dir, environment, stack_type)
      Bundler.with_clean_env do
        tf = Tempfile.new

        begin
          pid = Process.spawn(
            {
              'SF_ENV' => environment,
              'SF_PROJECT' => 'FIXME',
              'SF_COMPONENT' => 'FIXME',
              'SF_ACCOUNT_ALIAS' => 'FIXME',
              'SF_REGION' => 'FIXME',
              'AWS_REGION' => 'FIXME',
            },
            # FIXME split out "clean-modav-spud" from "generate-template"
            'clean-modav-spud', 'sh', '-c', "./src/#{stack_type}/generate-template > #{Shellwords.shellescape tf.path}",
            in: '/dev/null',
            chdir: stack_dir,
          )
          Process.wait pid
          $?.success? or raise "template generation failed"

          tf.rewind
          tf.read
        ensure
          tf.close
          tf.unlink
        end
      end
    end

  end
end
