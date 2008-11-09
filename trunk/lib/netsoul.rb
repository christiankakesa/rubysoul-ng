=begin
  Made by Christian KAKESA etna_2008(paris) <christian.kakesa@gmail.com>
=end

begin
  require 'socket'
  require 'singleton'
  require 'lib/netsoul_location'
  require 'lib/netsoul_message'
rescue LoadError
  puts "Error: #{$!}"
  exit
end

module NetSoul
  class NetSoul
    include Singleton

    attr_accessor :sock
    attr_reader :config, :connection_values, :connected, :authenticated

    def initialize
      @rs_config = RsConfig::instance()
      @connection_values = Hash.new
      @sock = nil
      @connected = false
      @authenticated = false
    end

    def connect
      @sock = nil
      @sock = TCPSocket.new(@rs_config.conf[:server_host].to_s, @rs_config.conf[:server_port].to_i)
      if (@sock.closed?)
        return false
      end
      buf = sock_get
      cmd, socket_num, md5_hash, client_ip, client_port, server_timestamp = buf.split
      server_timestamp_diff = Time.now.to_i - server_timestamp.to_i
      @connection_values[:md5_hash] = md5_hash
      @connection_values[:client_ip] = client_ip
      @connection_values[:client_port] = client_port
      @connection_values[:login] = @rs_config.conf[:login]
      @connection_values[:socks_password] = @rs_config.conf[:socks_password]
      @connection_values[:unix_password] = @rs_config.conf[:unix_password]
      @connection_values[:state] = @rs_config.conf[:state]
      @connection_values[:location] = @rs_config.conf[:location]
      @connection_values[:user_group] = @rs_config.conf[:user_group]
      @connection_values[:system] = RUBY_PLATFORM
      @connection_values[:timestamp_diff] = server_timestamp_diff
      return auth
    end

    def auth
      sock_send("auth_ag ext_user none -")
      if (sock_get().split(' ')[1] == "002")
        @connected = true
      else
        return false
      end

      if (@rs_config.conf[:unix_password].to_s.length > 0)
        sock_send(Message.kerberos_authentication(@connection_values))
      else
        sock_send(Message.standard_authentication(@connection_values))
      end

      if (sock_get().split(' ')[1] == "002")
        @authenticated = true
        sock_send("user_cmd attach")
        sock_send( Message.set_state(@rs_config.conf[:state], get_server_timestamp()) )
      else
        return false
      end
      return true
    end

    def disconnect
      sock_send(Message.ns_exit())
      @authenticated = false
      sock_close
      @connected = false
    end

    def sock_send(string)
      if (!@sock.closed? && string.to_s.length > 0)
        @sock.puts string
      else
        @authenticated = false
        @connected = false
      end
    end

    def sock_get
      if (!@sock.closed?)
        response = @sock.gets
        response = response.to_s.chomp if response
        return response
      else
        @authenticated = false
        @connected = false
        return ""
      end
    end

    def sock_close
      if (!@sock.closed?)
        @sock.close()
      end
    end

    def get_server_timestamp
      Time.now.to_i - @connection_values[:timestamp_diff].to_i
    end
  end
end
