# frozen_string_literal: true

module Gw
  class CLI
    def self.start(argv)
      new(argv).run
    end

    def initialize(argv)
      @argv = argv
    end

    def run
      command = @argv[0]

      case command
      when "init"
        handle_init
      when "repo"
        handle_repo
      when "add"
        handle_add
      when "remove", "rm"
        handle_remove
      when "list", "ls"
        handle_list
      when "status", "st"
        handle_status
      when "prune"
        handle_prune
      when "go"
        handle_go
      when "config"
        handle_config
      else
        show_usage
        exit 1
      end
    rescue StandardError => e
      puts "Error: #{e.message}"
      exit 1
    end

    private

    def handle_init
      workspace = Config.workspace
      core_dir = Config.core_dir
      tree_dir = Config.tree_dir

      FileUtils.mkdir_p(core_dir)
      FileUtils.mkdir_p(tree_dir)

      puts "Initialized gw workspace at #{workspace}"
      puts "  core: #{core_dir}"
      puts "  tree: #{tree_dir}"
    end

    def handle_repo
      subcommand = @argv[1]

      case subcommand
      when "clone"
        handle_repo_clone
      else
        puts "Usage: gw repo clone <owner/repo> [--name <custom-name>]"
        exit 1
      end
    end

    def handle_repo_clone
      full_name = @argv[2]
      custom_name = nil

      # Parse --name option
      custom_name = @argv[4] if @argv[3] == "--name" && @argv[4]

      unless full_name
        puts "Error: repository name is required"
        puts "Usage: gw repo clone <owner/repo> [--name <custom-name>]"
        exit 1
      end

      repo = Repository.clone(full_name, custom_name: custom_name)
      puts "Successfully cloned #{full_name} as '#{repo.name}'"
      puts "  bare: #{repo.bare_path}"
      puts "  tree: #{repo.tree_dir}"
    end

    def handle_add
      target = @argv[1]

      unless target
        puts "Error: target is required"
        puts "Usage: gw add <repo-name>/<branch>"
        exit 1
      end

      # Parse repo-name/branch
      parts = target.split("/")
      if parts.length != 2
        puts "Error: invalid format. Use: <repo-name>/<branch>"
        exit 1
      end

      repo_name, branch = parts

      worktree = Worktree.add(repo_name, branch)
      puts "Successfully created worktree '#{branch}' for #{repo_name}"
      puts "  path: #{worktree.path}"
    end

    def handle_remove
      target = @argv[1]

      unless target
        puts "Error: target is required"
        puts "Usage: gw remove <repo-name>/<branch>"
        exit 1
      end

      # Parse repo-name/branch
      parts = target.split("/")
      if parts.length != 2
        puts "Error: invalid format. Use: <repo-name>/<branch>"
        exit 1
      end

      repo_name, branch = parts

      Worktree.remove(repo_name, branch)
      puts "Successfully removed worktree '#{branch}' for #{repo_name}"
    end

    def handle_list
      filter = @argv[1]

      repos = if filter
                [Repository.find(filter)]
              else
                Repository.list
              end

      if repos.empty?
        puts "No repositories found"
        return
      end

      # Collect all worktrees with repo/branch format
      all_worktrees = []
      repos.each do |repo|
        worktrees = repo.worktrees
        if worktrees.empty?
          all_worktrees << { repo: repo.name, branch: "(no worktrees)", path: "" }
        else
          worktrees.each do |wt|
            all_worktrees << { repo: repo.name, branch: wt.branch, path: wt.path }
          end
        end
      end

      # Calculate column widths
      max_combined = all_worktrees.map { |wt| "#{wt[:repo]}/#{wt[:branch]}".length }.max || 0
      combined_width = [max_combined + 2, 30].max

      puts "#{"WORKTREE".ljust(combined_width)}PATH"
      all_worktrees.each do |wt|
        if wt[:branch] == "(no worktrees)"
          puts "#{wt[:repo].ljust(combined_width)}#{wt[:branch]}"
        else
          combined = "#{wt[:repo]}/#{wt[:branch]}"
          puts "#{combined.ljust(combined_width)}#{wt[:path]}"
        end
      end
    end

    def handle_go
      target = @argv[1]

      unless target
        puts "Error: target is required"
        puts "Usage: gw go <repo>/<branch>"
        exit 1
      end

      # Parse repo-name/branch
      parts = target.split("/")
      if parts.length != 2
        puts "Error: invalid format. Use: <repo>/<branch>"
        exit 1
      end

      repo_name, branch = parts

      # Find repository and worktree
      repo = Repository.find(repo_name)
      worktree = Worktree.new(repo, branch)

      unless worktree.exist?
        puts "Error: Worktree '#{branch}' not found for #{repo_name}"
        exit 1
      end

      # Output path only (for cd command)
      puts worktree.path
    end

    def handle_config
      subcommand = @argv[1]
      key = @argv[2]
      value = @argv[3]

      case subcommand
      when "get"
        unless key
          puts "Error: key is required"
          puts "Usage: gw config get <key>"
          exit 1
        end
        result = Config.get(key)
        puts result if result
      when "set"
        unless key && value
          puts "Error: key and value are required"
          puts "Usage: gw config set <key> <value>"
          exit 1
        end
        Config.set(key, value)
        puts "Successfully set #{key} = #{value}"
      else
        puts "Usage: gw config {get|set} <key> [value]"
        exit 1
      end
    end

    def handle_status
      repo_name = @argv[1]

      unless repo_name
        puts "Error: repository name is required"
        puts "Usage: gw status <repo>"
        exit 1
      end

      repo = Repository.find(repo_name)
      worktrees = repo.worktrees

      if worktrees.empty?
        puts "No worktrees found for #{repo_name}"
        return
      end

      full_name = repo.full_name
      unless full_name
        puts "Error: Could not determine GitHub repository for #{repo_name}"
        exit 1
      end

      # Collect branch names
      branches = worktrees.map(&:branch)

      # Fetch PR info for all branches
      puts "Fetching PR info from GitHub..."
      pr_info = GitHub.find_prs_by_branches(full_name, branches)

      # Build table data
      rows = worktrees.map do |wt|
        pr = pr_info[wt.branch]
        {
          worktree: "#{repo_name}/#{wt.branch}",
          branch: wt.branch,
          pr_number: pr ? "##{pr[:number]}" : "-",
          state: pr ? pr[:state] : "-",
          title: pr ? truncate(pr[:title], 40) : "-"
        }
      end

      # Calculate column widths
      wt_width = [rows.map { |r| r[:worktree].length }.max, 20].max + 2
      pr_width = 8
      state_width = 8
      title_width = 42

      # Print table
      puts ""
      puts "#{"WORKTREE".ljust(wt_width)}#{"PR".ljust(pr_width)}#{"STATE".ljust(state_width)}TITLE"
      puts "-" * (wt_width + pr_width + state_width + title_width)

      rows.each do |row|
        state_colored = colorize_state(row[:state])
        puts "#{row[:worktree].ljust(wt_width)}#{row[:pr_number].ljust(pr_width)}#{state_colored.ljust(state_width + color_padding(row[:state]))}#{row[:title]}"
      end

      # Summary
      puts ""
      open_count = rows.count { |r| r[:state] == "OPEN" }
      merged_count = rows.count { |r| r[:state] == "MERGED" }
      closed_count = rows.count { |r| r[:state] == "CLOSED" }
      no_pr_count = rows.count { |r| r[:state] == "-" }

      summary = []
      summary << "#{open_count} open" if open_count > 0
      summary << "#{merged_count} merged" if merged_count > 0
      summary << "#{closed_count} closed" if closed_count > 0
      summary << "#{no_pr_count} no PR" if no_pr_count > 0
      puts "Total: #{rows.length} worktrees (#{summary.join(", ")})"

      prunable = merged_count + closed_count
      puts "Run 'gw prune #{repo_name}' to remove #{prunable} completed worktrees" if prunable > 0
    end

    def handle_prune
      repo_name = @argv[1]
      dry_run = @argv.include?("--dry-run")
      merged_only = @argv.include?("--merged")

      unless repo_name
        puts "Error: repository name is required"
        puts "Usage: gw prune <repo> [--dry-run] [--merged]"
        exit 1
      end

      repo = Repository.find(repo_name)
      worktrees = repo.worktrees

      if worktrees.empty?
        puts "No worktrees found for #{repo_name}"
        return
      end

      full_name = repo.full_name
      unless full_name
        puts "Error: Could not determine GitHub repository for #{repo_name}"
        exit 1
      end

      # Collect branch names
      branches = worktrees.map(&:branch)

      # Fetch PR info for all branches
      puts "Fetching PR info from GitHub..."
      pr_info = GitHub.find_prs_by_branches(full_name, branches)

      # Find worktrees to prune
      to_prune = worktrees.select do |wt|
        pr = pr_info[wt.branch]
        next false unless pr

        if merged_only
          pr[:state] == "MERGED"
        else
          %w[MERGED CLOSED].include?(pr[:state])
        end
      end

      if to_prune.empty?
        puts "No worktrees to prune"
        return
      end

      puts ""
      puts "Worktrees to remove:"
      to_prune.each do |wt|
        pr = pr_info[wt.branch]
        puts "  #{repo_name}/#{wt.branch} (#{pr[:state]}, ##{pr[:number]})"
      end
      puts ""

      if dry_run
        puts "[Dry run] Would remove #{to_prune.length} worktrees"
        return
      end

      print "Remove #{to_prune.length} worktrees? [y/N] "
      answer = $stdin.gets&.strip&.downcase
      unless answer == "y"
        puts "Aborted"
        return
      end

      # Remove worktrees
      to_prune.each do |wt|
        print "Removing #{repo_name}/#{wt.branch}..."
        begin
          Worktree.remove(repo_name, wt.branch, force: true)
          puts " done"
        rescue StandardError => e
          puts " failed: #{e.message}"
        end
      end

      puts ""
      puts "Removed #{to_prune.length} worktrees"
    end

    def truncate(str, max_length)
      return str if str.length <= max_length

      "#{str[0, max_length - 3]}..."
    end

    def colorize_state(state)
      case state
      when "OPEN"
        "\e[32m#{state}\e[0m"  # Green
      when "MERGED"
        "\e[35m#{state}\e[0m"  # Magenta
      when "CLOSED"
        "\e[31m#{state}\e[0m"  # Red
      else
        state
      end
    end

    def color_padding(state)
      %w[OPEN MERGED CLOSED].include?(state) ? 9 : 0
    end

    def show_usage
      puts <<~USAGE
        Usage:
          gw init                                    Initialize gw workspace
          gw repo clone <owner/repo>                 Clone repository
          gw repo clone <owner/repo> --name <name>   Clone with custom name
          gw add <repo>/<branch>                     Add worktree
          gw remove <repo>/<branch>                  Remove worktree
          gw list [repo]                             List worktrees
          gw status <repo>                           Show worktrees with PR status
          gw prune <repo> [--dry-run] [--merged]    Remove merged/closed worktrees
          gw go <repo>/<branch>                      Print worktree path
          gw config get <key>                        Get config value
          gw config set <key> <value>                Set config value

        Examples:
          gw init
          gw repo clone aileron-inc/tools
          gw repo clone org/app --name custom-app
          gw add tools/feature-1
          gw list
          gw list tools
          gw status tools                            # Show PR status for all worktrees
          gw prune tools --dry-run                   # Preview what would be removed
          gw prune tools                             # Remove merged/closed worktrees
          gw prune tools --merged                    # Remove only merged worktrees
          cd $(gw go tools/feature-1)
          gw remove tools/feature-1
          gw config set workspace ~/my-workspace
      USAGE
    end
  end
end
