# frozen_string_literal: true

require "fileutils"

module Gw
  class Repository
    attr_reader :name, :bare_path

    def initialize(name, full_name = nil)
      @name = name
      @_full_name = full_name
      @bare_path = File.join(Config.core_dir, name)
    end

    # Get full_name (owner/repo) from remote URL
    def full_name
      return @_full_name if @_full_name

      @_full_name ||= begin
        remote_url = `git -C #{bare_path} remote get-url origin 2>/dev/null`.strip
        return nil if remote_url.empty?

        # Parse GitHub URL: https://github.com/owner/repo.git or git@github.com:owner/repo.git
        if remote_url =~ %r{github\.com[/:]([^/]+)/([^/]+?)(?:\.git)?$}
          "#{::Regexp.last_match(1)}/#{::Regexp.last_match(2)}"
        end
      end
    end

    def self.clone(full_name, custom_name: nil)
      repo_name = custom_name || full_name.split("/").last
      repo = new(repo_name, full_name)

      raise Error, "Repository '#{repo_name}' already exists" if repo.exist?

      FileUtils.mkdir_p(Config.core_dir)

      # Clone as bare repository with GitHub token authentication
      token = GitHub.token
      clone_url = "https://#{token}@github.com/#{full_name}.git"
      success = system("git clone --bare #{clone_url} #{repo.bare_path}")

      raise Error, "Failed to clone repository" unless success

      # Create tree directory for this repo
      FileUtils.mkdir_p(File.join(Config.tree_dir, repo_name))

      repo
    end

    def self.list
      return [] unless Dir.exist?(Config.core_dir)

      Dir.children(Config.core_dir).map do |name|
        new(name)
      end.select(&:exist?)
    end

    def self.find(name)
      repo = new(name)
      raise RepositoryNotFoundError, "Repository '#{name}' not found" unless repo.exist?

      repo
    end

    def exist?
      Dir.exist?(bare_path) && File.exist?(File.join(bare_path, "HEAD"))
    end

    def tree_dir
      File.join(Config.tree_dir, name)
    end

    def worktrees
      Worktree.list(self)
    end

    def default_branch
      return @default_branch if @default_branch

      # Try to get from GitHub if full_name is available
      if full_name
        @default_branch = GitHub.default_branch(full_name)
      else
        # Fallback: read from bare repository
        head_file = File.join(bare_path, "HEAD")
        content = File.read(head_file).strip
        @default_branch = content.match(%r{ref: refs/heads/(.+)})&.[](1) || "main"
      end

      @default_branch
    end

    def fetch
      puts "Fetching latest changes from remote..."
      success = system("git -C #{bare_path} fetch --all --prune")
      raise Error, "Failed to fetch from remote" unless success

      true
    end
  end
end
