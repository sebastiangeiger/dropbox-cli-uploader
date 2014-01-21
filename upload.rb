require 'pry'
require 'dropbox_sdk'
require 'yaml'
require 'logger'

class MyDropboxClient
  CONFIG_FILE = 'config.yml'
  def initialize
    @log = Logger.new(STDOUT)
    @log.level = Logger::DEBUG
  end

  def sign_in_if_needed!
    @config = if File.file?(CONFIG_FILE)
                YAML::load_file(CONFIG_FILE)
              else
                create_config_file
              end
    unless @config.has_key?(:access_token)
      @config = write_config(sign_in(config))
    end
  end

  def client
    if @client.nil?
      @client = DropboxClient.new(@config[:access_token])
      @log.info "Signed in as #{client.account_info()["email"]}"
    end
    @client
  end

  def upload(path)
    response = client.put_file("/#{path}", path)
    @log.debug(response.inspect)
  end

  private
  def write_config(config)
    File.open(CONFIG_FILE, "w+") do |file|
      file.write(YAML::dump(config))
    end
    @log.debug("Wrote #{config.inspect} to #{CONFIG_FILE}")
    config
  end

  def create_config_file
    config = {}
    puts "Please enter your APP KEY:"
    config[:app_key] = $stdin.gets.chomp
    puts "Please enter your APP SECRET:"
    config[:app_secret] = $stdin.gets.chomp
    write_config(config)
  end

  def sign_in(config)
    flow = DropboxOAuth2FlowNoRedirect.new(config[:app_key], config[:app_secret])
    authorize_url = flow.start()
    puts '1. Go to: ' + authorize_url
    puts '2. Click "Allow" (you might have to log in first)'
    puts '3. Copy the authorization code'
    print 'Enter the authorization code here: '
    code = $stdin.gets.chomp
    config[:access_token], config[:user_id] = flow.finish(code.strip)
    write_config(config)
  end

end

if __FILE__ == $0
  client = MyDropboxClient.new
  client.sign_in_if_needed!
  client.upload(ARGV.first)
end
