=begin
  Made by Christian KAKESA etna_2008(paris) <christian.kakesa@gmail.com>

  # TODO: save the config.yml file into user home dir (ie. :#{ENV['HOME']}/.rubysoul-ng/config.yml) 
=end

begin
	require 'ftools'
	require 'glib2'
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
  APP_VERSION = "0.9.8b"
  AUTHOR_NAME = "Christian"
  AUTHOR_FIRSTNAME = "KAKESA"
  AUTHOR_FULLNAME = "#{AUTHOR_NAME} #{AUTHOR_FIRSTNAME}"
  AUTHOR_EMAIL = "christian.kakesa@gmail.com"
  AGENT = APP_NAME + " - V" + APP_VERSION
  DEFAULT_SIZE_W = 260
  DEFAULT_SIZE_H = 420

  #CONFIG_FILENAME = "#{APP_DIR+File::SEPARATOR}data#{File::SEPARATOR}config.yml"
  #CONTACTS_FILENAME = "#{APP_DIR+File::SEPARATOR}data#{File::SEPARATOR}contacts.yml"
  #CONTACTS_PHOTO_DIR = "#{APP_DIR+File::SEPARATOR}data#{File::SEPARATOR}contacts_photo"
  #CONTACTS_PHOTO_URL = "http://intra.epitech.eu/intra/photo.php?login=" #TODO try to detect if in PIE

  @@theme_name = "msn"
  THEME_DIR = "#{APP_DIR+File::SEPARATOR}themes#{File::SEPARATOR+@@theme_name}"

  ## ICONS ##
  ###########
  ICON_CONNECT = "#{THEME_DIR+File::SEPARATOR}Connect.png"
  ICON_MULTICONNECT = "#{THEME_DIR+File::SEPARATOR}Multiconnect.png"
  ICON_DISCONNECT = "#{THEME_DIR+File::SEPARATOR}Disconnect.png"
  ICON_OFFLINE = "#{THEME_DIR+File::SEPARATOR}Offline.png"
  ICON_STATE_ACTIF = "#{THEME_DIR+File::SEPARATOR}StateActif.png"
  ICON_STATE_LOGIN = "#{THEME_DIR+File::SEPARATOR}StateLogin.png"
  ICON_STATE_CONNECTION = "#{THEME_DIR+File::SEPARATOR}StateConnection.png"
  ICON_STATE_AWAY = "#{THEME_DIR+File::SEPARATOR}StateAway.png"
  ICON_STATE_IDLE = "#{THEME_DIR+File::SEPARATOR}StateIdle.png"
  ICON_STATE_BUSY = "#{THEME_DIR+File::SEPARATOR}StateBusy.png"
  ICON_STATE_LOCK = "#{THEME_DIR+File::SEPARATOR}StateLock.png"
  ICON_STATE_SERVER = "#{THEME_DIR+File::SEPARATOR}StateServer.png"
  ICON_STATE_LOGOUT = "#{THEME_DIR+File::SEPARATOR}StateLogout.png"
  ICON_STATE_DISCONNECT = "#{THEME_DIR+File::SEPARATOR}StateDisconnect.png"

  attr_accessor :conf
  attr_reader		:config_filename, :contacts_filename, :contacts_photo_dir, :contacts_photo_url

  def initialize
  	begin
    	my_config_home_init()
    	my_data_home_init()
    rescue
    	puts "Error: #{$!}"; exit;
    end
    load_config()
  end
  
  def my_config_home_init
  	if not GLib.getenv('XDG_config_home')
  		config_home = GLib.home_dir+File::SEPARATOR+'.config'
  		@config_filename = config_home+File::SEPARATOR+APP_NAME.downcase()+File::SEPARATOR+'config.yml'
  	else
  		config_home = GLib.getenv('XDG_config_home')
  		@config_filename = config_home+File::SEPARATOR+APP_NAME.downcase()+File::SEPARATOR+'config.yml'
  	end
  	if not FileTest.exist?(@config_filename)
  		if not FileTest.exist?(config_home+File::SEPARATOR+APP_NAME.downcase())
  			File.makedirs(config_home+File::SEPARATOR+APP_NAME.downcase())
  		end
  		if not File.directory?(config_home+File::SEPARATOR+APP_NAME.downcase())
  			File.delete(config_home+File::SEPARATOR+APP_NAME.downcase())
  			File.makedirs(config_home+File::SEPARATOR+APP_NAME.downcase())
  		end
  		File.open(@config_filename, File::CREAT|File::RDWR, 0600) do |f|
  			f.write( ":login: \n:socks_password: \n:unix_password: \n:server_host: ns-server.epita.fr\n:server_port: \"4242\"\n:connection_type: md5\n:connection_at_startup: true\n:user_group: IONIS\n:location: \"@ HOME\"\n:state: actif")
				f.close()
  		end
  	end
  end
  
  def my_data_home_init
  	if not GLib.getenv('XDG_data_home')
  		data_home = GLib.home_dir+File::SEPARATOR+'.local'+File::SEPARATOR+'share'
  		@contacts_filename = data_home+File::SEPARATOR+APP_NAME.downcase()+File::SEPARATOR+'contacts.yml'
  	else
  		config_home = GLib.getenv('XDG_data_home')
  		@contacts_filename = data_home+File::SEPARATOR+APP_NAME.downcase()+File::SEPARATOR+'contacts.yml'
  	end
  	if not FileTest.exist?(@contacts_filename)
  		if not FileTest.exist?(data_home+File::SEPARATOR+APP_NAME.downcase())
  			File.makedirs(data_home+File::SEPARATOR+APP_NAME.downcase())
  		end
  		if not File.directory?(data_home+File::SEPARATOR+APP_NAME.downcase())
  			File.delete(data_home+File::SEPARATOR+APP_NAME.downcase())
  			File.makedirs(data_home+File::SEPARATOR+APP_NAME.downcase())
  		end
  		File.new(@contacts_filename, File::CREAT, 0600)
  	end
  	@contacts_photo_dir = data_home+File::SEPARATOR+APP_NAME.downcase()+File::SEPARATOR+'contacts_photo'
  	if not FileTest.exist?(@contacts_photo_dir)
  		File.makedirs(@contacts_photo_dir)
  	end
  	if not File.directory?(@contacts_photo_dir)
  		File.delete(@contacts_photo_dir)
  		File.makedirs(@contacts_photo_dir)
  	end
  	if not in_pie?()
  		@contacts_photo_url = 'http://intra.epitech.eu/intra/photo.php?login='
  	else
  		@contacts_photo_url = 'http://intra/photo.php?login='
  	end
  end
  
  def in_pie? #TODO: need to be implemented
  	return false
  end

  def load_config
    @conf = YAML::load_file(@config_filename)
  end

  def save
    File.open(@config_filename, "wb") do |file|
      file.puts '#--- ! RubySoulNG config file'
      file.puts @conf.to_yaml
      file.close()
    end
  end
end

