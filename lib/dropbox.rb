require 'dropbox_api'

# dropbox class
class Dropbox
  attr_reader :url
  def initialize(project)
    token = project.config['dropbox_token']
    @logger = project.logger
    @timestamp = project.timestamp
    @tag = project.tag
    @dropbox = DropboxApi::Client.new(token)
    create_shared_folder
  end

  def create_shared_folder
    @path = "/#{@tag}-#{@timestamp}"
    @dropbox.create_folder(@path)
    @dropbox.share_folder(@path)
    @url = @dropbox.create_shared_link_with_settings(@path).url + '&lst='
    @logger.info("Dropbox shared folder: #{@url}")
  end

  def upload(file_path, file_name = nil)
    file_name = file_path.split('/').last if file_name.nil?
    ext = file_path.split('.').last
    file_content = IO.read(file_path)
    remote_path = @path + '/' + file_name + '.' + ext
    @dropbox.upload(remote_path, file_content)
    @logger.info('File uploaded to dropbox shared folder')
  end

  def upload_text(content, file_name)
    remote_path = @path + '/' + file_name
    @dropbox.upload(remote_path, content, mode: 'overwrite')
    @logger.info('Logs uploaded to dropbox shared folder')
  end
end
