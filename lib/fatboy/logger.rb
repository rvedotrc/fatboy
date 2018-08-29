module Fatboy
  class Logger

    def initialize(io = nil)
      @mutex = Mutex.new
      @io = io || $stdout
    end

    def puts(*args)
      str = args.map(&:to_s).join($/)
      @mutex.synchronize do
        @io.puts(str)
      end
    end

    def to_pipe
      r,w = IO.pipe

      Thread.new do
        w.close
        r.each_line do |t|
          puts t
        end
      end

      r.close
      w
    end

  end
end
