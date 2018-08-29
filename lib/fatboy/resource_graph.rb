require 'rosarium'

module Fatboy
  class ResourceGraph

    def initialize(context)
      @context = context
      @resources = {}
      @depends_on = {}
      @mutex = Mutex.new
    end

    def register_resource(key, resource, depends_on = nil)
      @mutex.synchronize do
        if @resources.has_key? key
          raise "Already got resource #{key.inspect}"
        end

        @resources[key] = resource
        @depends_on[key] = depends_on if depends_on
      end
    end

    def invert
      other = self.class.new

      @resources.each_entry do |k, r|
        reverse_dependencies = @depends_on.keys.select do |dep|
          @depends_on[dep].include? k
        end
        other.register_resource(k, r, reverse_dependencies)
      end

      other
    end

    def dump
      @resources.keys.sort.each do |k|
        @context.logger.puts "#{k} #{@resources[k]}"
        (@depends_on[k] || []).sort.each do |dep|
          @context.logger.puts "  depends on #{dep}"
        end
      end
    end

    def to_graphviz
      require 'ruby-graphviz'
      g = GraphViz.new("G")

      @resources.keys.sort.each do |k|
        g.add_node(k)
      end

      @resources.keys.sort.each do |k|
        (@depends_on[k] || []).sort.each do |dep|
          g.add_edge(k, dep)
        end
      end

      g
    end

    def make_promise(method)
      trigger = Rosarium::Promise.defer

      promises = {}

      loop do
        to_create = @resources.keys - promises.keys
        break if to_create.empty?

        can_create = to_create.select do |k|
          @depends_on[k].nil? or @depends_on[k].all? do |dep|
            promises.has_key? dep
          end
        end

        if can_create.empty?
          raise "Dependency cycle detected"
        end

        can_create.each do |k|
          deps = @depends_on[k] || []

          parent = if deps.empty?
                     trigger.promise
                   else
                     Rosarium::Promise.all(deps.map {|dep| promises[dep]})
                   end

          promises[k] = parent.then do
            begin
              @context.logger.puts "STARTING #{method} #{k}"
              @resources[k].send(method)
              @context.logger.puts "SUCCESS #{method} #{k}"
            rescue Exception => e
              @context.logger.puts "FAILURE #{method} #{k}"
              raise
            end
          end
        end
      end

      trigger.resolve nil

      Rosarium::Promise.all(promises.values).catch do |e|
        # If at least one failed, wait for everything to settle, then report
        # on what failed.  No need if everything worked, of course.
        Rosarium::Promise.all_settled(promises.values).then do |l|
          promises.each_entry do |k, v|
            if v.rejected?
              @context.logger.puts "FAILED: #{k} #{v.reason}"
            else
              @context.logger.puts "SUCCEEDED: #{k}"
            end
          end
          raise e
        end
      end
    end

  end
end
