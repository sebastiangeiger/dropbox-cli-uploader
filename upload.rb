require 'pry'
require 'dropbox_sdk'
require 'yaml'
require 'logger'

class DropboxCliUploader
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
      @config = write_config(sign_in(@config))
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
    file_size = File.size(path)
    megabytes = (file_size/(1024*1024))
    dropbox_path = "/#{path}"
    if megabytes < 10
      @log.debug("Uploading #{path} via regular upload")
      response = client.put_file(dropbox_path, path)
      @log.debug(response.inspect)
    else
      @log.debug("Uploading #{path} via chunked upload")
      file = File.open(path, "r")
      uploader = DropboxClient::ChunkedUploader.new(client, file, file_size)
      uploader.upload
      @log.debug(uploader.finish(dropbox_path))
    end
    @log.info "Uploaded #{path} to #{dropbox_path}"
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
  client = DropboxCliUploader.new
  client.sign_in_if_needed!
  ARGV.each do |file|
    client.upload(file)
  end
end
