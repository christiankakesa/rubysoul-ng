=begin
  Made by Christian KAKESA etna_2008(paris) <christian.kakesa@gmail.com>
=end

begin
  require 'uri'
  require 'digest/md5'
  require 'rs_config'
  require 'rs_infobox'
rescue LoadError
  puts "Error: #{$!}"
end

module NetSoul
  class Message
    def self.standard_authentication(connection_values)
      auth_string = Digest::MD5.hexdigest('%s-%s/%s%s'%[	connection_values[:md5_hash],
      connection_values[:client_ip],
      connection_values[:client_port],
      connection_values[:socks_password]	])
      return 'ext_user_log %s %s %s %s'%[	connection_values[:login],
      auth_string,
      Message::escape(Location::get(connection_values[:client_ip]) == "ext" ? connection_values[:location] : Location::get(connection_values[:client_ip])),
    Message::escape("#{RsConfig::APP_NAME} #{RsConfig::APP_VERSION}")]
  end

  def self.kerberos_authentication(connection_values)
    begin
      require 'lib/kerberos/NsToken'
    rescue LoadError
      puts "Error: #{$!}"
      puts "Build the \"NsToken\" ruby/c extension if you don't.\nSomething like this : \"cd ./lib/kerberos && ruby extconf.rb && make\""
      exit
    end
    tk = NsToken.new
    if not tk.get_token(connection_values[:login], connection_values[:unix_password])
      puts "Impossible to retrieve the kerberos token !!!"
      exit
    end
    #puts "TOKEN_B64: #{tk.token_base64}"
    #puts "TOKEN_B64_LENGTH: #{tk.token_base64.length.to_s}"
    return 'ext_user_klog %s %s %s %s %s'%[tk.token_base64.slice(0, 812), Message::escape(connection_values[:system]), Message::escape(connection_values[:location]), Message::escape(connection_values[:user_group]), Message::escape("#{RsConfig::APP_NAME} #{RsConfig::APP_VERSION}")]
  end

  def self.send_message(user, msg)
    return 'user_cmd msg_user %s msg %s'%[user, Message::escape(msg)]
  end

  def self.start_writing_to_user(user)
    return 'user_cmd msg_user %s dotnetSoul_UserTyping null'%[user]
  end

  def self.stop_writing_to_user(user)
    return 'user_cmd msg_user %s dotnetSoul_UserCancelledTyping null'%[user]
  end

  def self.list_users(user_list)
    return 'list_users {%s}'%[user_list]
  end

  def self.who_users(user_list)
    return 'user_cmd who {%s}'%[user_list]
  end

  def self.watch_users(user_list)
    return 'user_cmd watch_log_user {%s}'%[user_list]
  end

  def self.set_state(state, timestamp)
    return 'user_cmd state %s:%s'%[state.to_s, timestamp.to_s]
  end

  def self.set_user_data(data)
    return 'user_cmd user_data %s'%[Message::escape(data)]
  end

  def self.ping
    return "ping 42"
  end

  def self.ns_exit
    return "exit"
  end

  def self.escape(str)
    str = URI.escape(str)
    URI.escape(str, "\ :'@~\[\]&()=*$!;,\+\/\?")
  end

  def self.ltrim(str)
    return str.gsub(/^\s+/, '')
  end

  def self.rtrim(str)
    return str.gsub(/\s+$/, '')
  end

  def self.trim(str)
    str = Message::ltrim(str)
    str = Message::rtrim(str)
    return str
  end
end
end
