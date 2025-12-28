module Kc
  class CLI
    def self.start(argv)
      new(argv).run
    end

    def initialize(argv)
      @argv = argv
    end

    def run
      command = @argv[0]
      service_name = @argv[1]

      case command
      when "save"
        handle_save(service_name)
      when "load"
        handle_load(service_name)
      when "delete"
        handle_delete(service_name)
      else
        show_usage
        exit 1
      end
    end

    private

    def handle_save(service_name)
      unless service_name
        puts "Error: service name is required"
        show_usage
        exit 1
      end

      # Read from stdin
      if STDIN.tty?
        puts "Error: No input provided. Use: cat .env | kc save <name>"
        exit 1
      end

      content = STDIN.read
      if content.empty?
        puts "Error: Input is empty"
        exit 1
      end

      Keychain.save(service_name, content)
      puts "Successfully saved to keychain as '#{service_name}'"
    rescue => e
      puts "Error: #{e.message}"
      exit 1
    end

    def handle_load(service_name)
      unless service_name
        puts "Error: service name is required"
        show_usage
        exit 1
      end

      content = Keychain.load(service_name)
      puts content
    rescue => e
      puts "Error: #{e.message}"
      exit 1
    end

    def handle_delete(service_name)
      unless service_name
        puts "Error: service name is required"
        show_usage
        exit 1
      end

      Keychain.delete(service_name)
      puts "Successfully deleted '#{service_name}' from keychain"
    rescue => e
      puts "Error: #{e.message}"
      exit 1
    end

    def show_usage
      puts <<~USAGE
        Usage:
          cat .env | kc save <name>   Save from stdin to keychain
          kc load <name>              Load from keychain to stdout
          kc delete <name>            Delete from keychain
      USAGE
    end
  end
end
