=begin
  NetSoul Socket for RSOULng.
=end
begin
  require 'config'
rescue LoadError
end

class RubySoulSocket
  attr_reader :sock, :logger, :debug, :location, :state, :socket_num, :client_host, :client_port, :pre_cmd, :user_from
  attr_accessor :user, :current_cmd

  def self.initialize
    @sock = nil
    @current_cmd = nil
    @logger = Logger.new('logfile.log', 7, 1024000)
    @user_from = nil ## extern or internal client connexion
    begin
      @user = YAML.load_file("user_prefs.yml");
    rescue
      @user = nil
      log_error("Can't load user prefs from user_prefs.yml file")
    end	
  end
  
  def connect
    begin
      if not (@sock)
    	@sock  = TCPSocket.new(RS_HOST, RS_PORT)
      end
      if not (@logger)
        @logger = Logger.new('logfile.log', 7, 1024000)
      end
    rescue
      return false
    else
      return sock_get()
    end
  end
  
  def disconnect
    sock_send("exit")
    sock_close()
  end
  
  def auth(login, pass, user_ag, state)
    msg = connect()
    @state = state
    cmd, @socket_num, md5_hash, @client_host, @client_port, server_timestamp = msg.split
    data = YAML.load_file("data/data_config.yml")
    @user_from = "ext"
    @auth_cmd = "user"
    @cmd = "cmd"
    data["iptable"].each do |key, val|
      res = @client_host.match(/^#{val}/)
      if res != nil
        res = "#{key}".chomp
        @location = res + "-" + RS_APP_NAME + " V" + RS_VERSION
        @user_from = res
        break
      end
    end
    if (@user_from == "ext")
      @auth_cmd = "ext_user"
      @cmd = "user_cmd"
      @location = @user[:location] + "-" + RS_APP_NAME + " V" + RS_VERSION
    end 
    reply_hash = Digest::MD5.hexdigest("%s-%s/%s%s" % [md5_hash, @client_host, @client_port, pass])
    sock_send("auth_ag " + @auth_cmd + " none none")
    sock_send(@auth_cmd + "_log " + login + " " + reply_hash + " " + Socket::escape(@location) + " " + Socket::escape(user_ag))
    sock_send("user_cmd attach")
    sock_send("user_cmd state " + state + ":" + Time.now.to_i.to_s) #--- ! get time stamp like rubysoul or rubysoul-server
    return true
  end
  
  def get_os
    case RUBY_PLATFORM
    when /linux/
      return "linux"
    when /mswin32/
      return "win32"
    when /bsd/
      return "bsd"
    else
      return true
    end
  end
  
  def get_ip(fqn_host)
    ss = IPSocket::getaddress(fqn_host)
    ss.chomp
    return ss
  end
  
  def send_msg(users, msg)
    sock_send(@cmd + " msg_user {" + users + "} msg " + Socket::escape(msg))
  end
  
  #--- ! Commande n'est plus gere
  ## def fListUsers(users)
  ##  sock_send("list_users {" + users + "}")
  ##  @current_cmd = "list_users"
  ## end
  
  def watch_users(users)
    sock_send(@cmd + " watch_log_user {" + users + "}")
    ## @current_cmd = "watch_log_user"
  end
  
  def who_users(users)
    sock_send(@cmd + " who {" + users + "}")
    ## @current_cmd = "who"
  end
  
  def set_user_status(status)
    @user[:status] = status
    sock_send(@cmd + " state " + status + ":" + Time.now.to_i.to_s) #--- ! get time stamp like rubysoul or rubysoul-server
  end
  
  def sock_send(string)
    if (@sock)
      @sock.puts string
      log_debug("[send] : " + string)
    end
  end
  
  def sock_get
    if (@sock)
      response = @sock.gets.to_s.chomp
      log_debug("[gets] : " + response)
      return response
    end
  end
  
  def sock_close
    if (@sock)
      @sock.close
      @sock = nil
      @current_cmd = nil
    end
  end
  
  def log_error(string)
    if (@logger)
      @logger.error(RS_APP_NAME) {string}
    end
  end
  
  def log_warn(string)
    if (@logger)
      @logger.warn(RS_APP_NAME) {string}
    end
  end
  
  def log_debug(string)
    if (@logger)
      @logger.debug(RS_APP_NAME) {string}
    end
  end
  
  def log_info(string)
    if (@logger)
      @logger.info(RS_APP_NAME) {string}
    end
  end
  
  def log_fatal(string)
    if (@logger)
      @logger.fatal(RS_APP_NAME) {string}
    end
  end
  
  def log_close
    if (@logger)
      @logger.close
      @logger = nil
    end
  end
  
  def self.escape(str)
    str = URI.escape(str)
    res = URI.escape(str, "\ :'@~\[\]&()=*$!;,\+\/\?")
    return res
  end
end
