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

      unless File.exist?(".env")
        puts "Error: .env file not found in current directory"
        exit 1
      end

      content = File.read(".env")
      Keychain.save(service_name, content)
      puts "Successfully saved .env to keychain as '#{service_name}'"
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

    def show_usage
      puts <<~USAGE
        Usage:
          kc save <service-name>  Save .env file to keychain
          kc load <service-name>  Load .env content from keychain
      USAGE
    end
  end
end
