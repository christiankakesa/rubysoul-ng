=begin
  Made by Christian KAKESA etna_2008(paris) <christian.kakesa@gmail.com>

  # TODO: save the config.yml file into user home dir (ie. :#{ENV['HOME']}/.rubysoul-ng/config.yml) 
=end

begin
  require 'yaml'
  require 'singleton'
rescue LoadError
  puts "Error: #{$!}"
  exit
end

class RsConfig
  include Singleton

  ## APPLICATION CONFIG ##
  ########################
  APP_NAME = "RubySoul-NG"
  APP_DIR = "#{File.dirname(__FILE__)}"
  APP_VERSION = "0.1.3a"
  AUTHOR_NAME = "Christian"
  AUTHOR_FIRSTNAME = "KAKESA"
  AUTHOR_FULLNAME = "#{AUTHOR_NAME} #{AUTHOR_FIRSTNAME}"
  AUTHOR_EMAIL = "christian.kakesa@gmail.com"
  AGENT = APP_NAME + " - V" + APP_VERSION
  DEFAULT_SIZE_W = 300
  DEFAULT_SIZE_H = 600

  CONFIG_FILENAME = "#{APP_DIR+File::SEPARATOR}data#{File::SEPARATOR}config.yml"
  CONTACTS_FILENAME = "#{APP_DIR+File::SEPARATOR}data#{File::SEPARATOR}contacts.yml"
  CONTACTS_PHOTO_DIR = "#{APP_DIR+File::SEPARATOR}data#{File::SEPARATOR}contacts_photo#{File::SEPARATOR}"
  CONTACTS_PHOTO_URL = "http://intra.epitech.eu/intra/photo.php?login="

  @@theme_name = "msn"
  THEME_DIR = "#{APP_DIR+File::SEPARATOR}themes#{File::SEPARATOR+@@theme_name}"

  ## ICONS ##
  ###########
  ICON_CONNECT = "#{THEME_DIR+File::SEPARATOR}Connect.png"
  ICON_MULTICONNECT = "#{THEME_DIR+File::SEPARATOR}Multiconnect.png"
  ICON_DISCONNECT = "#{THEME_DIR+File::SEPARATOR}Disconnect.png"
  ICON_STATE_ACTIVE = "#{THEME_DIR+File::SEPARATOR}StateOnline.png"
  ICON_STATE_AWAY = "#{THEME_DIR+File::SEPARATOR}StateAway.png"
  ICON_STATE_IDLE = "#{THEME_DIR+File::SEPARATOR}StateIdle.png"
  ICON_STATE_LOCK = "#{THEME_DIR+File::SEPARATOR}StateLock.png"
  ICON_STATE_SERVER = "#{THEME_DIR+File::SEPARATOR}StateServer.png"
  ICON_STATE_DISCONNECT = "#{THEME_DIR+File::SEPARATOR}StateDisconnect.png"

  attr_accessor :conf

  def initialize
    load_config()
  end

  def load_config
    @conf = YAML::load_file(CONFIG_FILENAME)
  end

  def save
    File.open(CONFIG_FILENAME, "wb") do |file|
      file.puts '#--- ! RubySoulNG config file'
      file.puts @conf.to_yaml
      file.close()
    end
  end
end

