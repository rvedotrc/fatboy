require 'fileutils'
require 'weakref'

module Fatboy
  class ScmHelper

    def initialize(context)
      @context = WeakRef.new(context)
      @base_dir = '/tmp/fatboy/git_clones'
    end

    def git_clone(git_url, git_revision)
      key = File.basename(git_url.sub(/.git$/, "")) \
        + "-" + git_revision.gsub('/', '') \
        + "-" + Digest::SHA1.hexdigest(git_url)
      dir = @base_dir + "/" + key

      if s = begin ; File.lstat(dir) ; rescue Errno::ENOENT ; end \
          and s.directory? \
          and s.mtime >= Time.now - 1800
        return dir
      end

      FileUtils.rm_rf dir
      FileUtils.mkdir_p @base_dir

      @context.logger.puts "git clone #{git_url} #{dir}"
      Process.wait(
        Process.spawn(
          "git", "clone", git_url, dir,
          in: '/dev/null',
          out: @context.logger.to_pipe,
          err: @context.logger.to_pipe,
        )
      )
      $?.success? or raise "git clone #{git_url} failed"

      @context.logger.puts "git checkout #{git_revision}"
      Process.wait(
        Process.spawn(
          "git", "checkout", git_revision,
          in: '/dev/null',
          out: @context.logger.to_pipe,
          err: @context.logger.to_pipe,
          chdir: dir,
        )
      )
      $?.success? or raise "git checkout #{git_revision} failed"

      dir
    end
    
  end
end
