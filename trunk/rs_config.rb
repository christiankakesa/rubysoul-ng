=begin
	Made by Christian KAKESA etna_2008(paris) <christian.kakesa@gmail.com>
=end

begin
	require 'ftools'
	require 'glib2'
	require 'yaml'
	require 'singleton'
rescue LoadError
	puts "Error: #{$!}"; exit!;
end

class RsConfig
	include Singleton

	## APPLICATION CONFIG ##
	########################
	APP_NAME = "RubySoul-NG"
	APP_DIR = "#{File.dirname(__FILE__)}"
	APP_VERSION = "1.0.0"
  APP_USER_AGENT = APP_NAME + " v" + APP_VERSION
  APP_CONNECTION_TYPE_MD5 = 'md5'
  APP_CONNECTION_TYPE_KERBEROS = 'kerberos'

	AUTHOR_NAME = "Christian"
	AUTHOR_FIRSTNAME = "Kakesa"
	AUTHOR_FULLNAME = "#{AUTHOR_NAME} #{AUTHOR_FIRSTNAME}"
	AUTHOR_EMAIL = "christian.kakesa@gmail.com"
	AUTHOR_PROMO = "etna-2008"

  DEFAULT_SIZE_W = 290
	DEFAULT_SIZE_H = 420
  DEFAULT_NETSOUL_SERVER_HOST = 'ns-server.epitech.net'
  DEFAULT_NETSOUL_SERVER_PORT = '4242'
  DEFAULT_NETSOUL_CONNECTION_TYPE = APP_CONNECTION_TYPE_KERBEROS
  DEFAULT_NETSOUL_CONNECTION_AT_STARTUP = false
  DEFAULT_NETSOUL_USER_GROUP = 'IONIS'
  DEFAULT_NETSOUL_LOCATION = '@NETWORK'
  DEFAULT_NETSOUL_STATUS = 'actif'
  DEFAULT_PROXY_HTTP_HOST = 'localhost'
  DEFAULT_PROXY_HTTP_PORT = '3128'
  DEFAULT_PROXY_HTTP_USE = false
  DEFAULT_PROXY_SOCKS5_HOST = 'localhost'
  DEFAULT_PROXY_SOCKS5_PORT = '1080'
  DEFAULT_PROXY_SOCKS5_USE = false

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
  attr_reader		:config_filename, :contacts_filename, :contacts_photo_dir, :contacts_photo_url, :contacts_photo_url_path

  def initialize
    begin
      my_config_home_init()
      my_data_home_init()
    rescue
      $log.error("Error: #{$!}")
    end
    load_config()
  end

  def my_config_home_init
    if not GLib.getenv('XDG_CONFIG_HOME')
      config_home = GLib.home_dir+File::SEPARATOR+'.config'
      @config_filename = config_home+File::SEPARATOR+APP_NAME.downcase()+File::SEPARATOR+'config.yml'
    else
      config_home = GLib.getenv('XDG_CONFIG_HOME')
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
        res =  ":login: \n"
        res += ":unix_password: \n"
        res += ":socks_password: \n"
        res += ":server_host: #{DEFAULT_NETSOUL_SERVER_HOST}\n"
        res += ":server_port: \"#{DEFAULT_NETSOUL_SERVER_PORT}\"\n"
        res += ":connection_type: #{DEFAULT_NETSOUL_CONNECTION_TYPE}\n"
        res += ":connection_at_startup: #{DEFAULT_NETSOUL_CONNECTION_AT_STARTUP}\n"
        res += ":user_group: #{DEFAULT_NETSOUL_USER_GROUP}\n"
        res += ":location: \"#{DEFAULT_NETSOUL_LOCATION}\"\n"
        res += ":state: #{DEFAULT_NETSOUL_STATUS}\n"
        res += ":proxy_http_host: #{DEFAULT_PROXY_HTTP_HOST}\n"
        res += ":proxy_http_port: \"#{DEFAULT_PROXY_HTTP_PORT}\"\n"
        res += ":proxy_http_use: #{DEFAULT_PROXY_HTTP_USE}\n"
        res += ":proxy_socks5_host: #{DEFAULT_PROXY_SOCKS5_HOST}\n"
        res += ":proxy_socks5_port: \"#{DEFAULT_PROXY_SOCKS5_PORT}\"\n"
        res += ":proxy_socks5_use: #{DEFAULT_PROXY_SOCKS5_USE}\n"
        res += ":proxy_username: \n"
        res += ":proxy_password: \n"
        f.write(res)
      end
    end
  end

  def my_data_home_init
		if not GLib.getenv('XDG_DATA_HOME')
			data_home = GLib.home_dir+File::SEPARATOR+'.local'+File::SEPARATOR+'share'
			@contacts_filename = data_home+File::SEPARATOR+APP_NAME.downcase()+File::SEPARATOR+'contacts.yml'
		else
			data_home = GLib.getenv('XDG_DATA_HOME')
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
		@contacts_photo_url = 'www.epitech.eu'
		@contacts_photo_url_path = 'intra/photo.php?login='
	end

	def load_config
		@conf = YAML::load_file(@config_filename)
	end

	def save
		File.open(@config_filename, "wb") do |file|
			file.puts '#--- ! RubySoulNG config file'
			file.puts @conf.to_yaml
		end
	end
end

