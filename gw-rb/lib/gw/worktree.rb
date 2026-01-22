# frozen_string_literal: true

module Gw
  class Worktree
    attr_reader :repository, :branch, :path

    def initialize(repository, branch, path = nil)
      @repository = repository
      @branch = branch
      @path = path || File.join(repository.tree_dir, branch)
    end

    def self.add(repo_name, branch)
      repo = Repository.find(repo_name)
      worktree = new(repo, branch)

      raise WorktreeAlreadyExistsError, "Worktree '#{branch}' already exists" if worktree.exist?

      # Fetch latest changes from remote
      repo.fetch

      # Check if branch exists (locally or remotely)
      branch_exists = system("git -C #{repo.bare_path} show-ref --verify --quiet refs/heads/#{branch}") ||
                      system("git -C #{repo.bare_path} show-ref --verify --quiet refs/remotes/origin/#{branch}")

      if branch_exists
        # Branch exists, checkout
        success = system("git -C #{repo.bare_path} worktree add #{worktree.path} #{branch}")
      else
        # Branch doesn't exist, create from default branch
        default_branch = repo.default_branch
        puts "Branch '#{branch}' not found. Creating from '#{default_branch}'..."
        success = system("git -C #{repo.bare_path} worktree add -b #{branch} #{worktree.path} #{default_branch}")
      end

      raise Error, "Failed to create worktree" unless success

      worktree
    end

    def self.remove(repo_name, branch, force: false)
      repo = Repository.find(repo_name)
      worktree = new(repo, branch)

      raise Error, "Worktree '#{branch}' not found" unless worktree.exist?

      # Remove worktree
      force_flag = force ? "--force" : ""
      success = system("git -C #{repo.bare_path} worktree remove #{force_flag} #{worktree.path}")

      raise Error, "Failed to remove worktree" unless success

      worktree
    end

    def self.list(repository)
      return [] unless Dir.exist?(repository.tree_dir)

      # Use git worktree list to get actual branch names
      output = `git -C #{repository.bare_path} worktree list --porcelain`
      return [] if output.empty?

      output.scan(/worktree (.+)/).map do |paths|
        path = paths[0]
        # Only include worktrees in this repo's tree_dir
        next unless path.start_with?(repository.tree_dir)

        # Get branch from git command
        branch = `git -C #{path} branch --show-current 2>/dev/null`.strip
        next if branch.empty?

        new(repository, branch, path)
      end.compact
    end

    def exist?
      Dir.exist?(path) && File.exist?(File.join(path, ".git"))
    end
  end
end
