=begin
  Made by Christian KAKESA etna_2008(paris) <christian.kakesa@gmail.com>
=end

begin
  require 'socket'
  require 'rs_config'
  require 'lib/netsoul_location'
  require 'lib/netsoul_message'
rescue LoadError
  puts "Error: #{$!}"
  exit
end

module NetSoul
  class NetSoul
    attr_accessor :sock
    attr_reader :config, :connection_values, :connected, :authentificated

    def initialize(config_filename)
      @config = YAML::load_file(config_filename)
      @connection_values = Hash.new
      @sock = nil
      @connected = false
      @authentificated = false
    end

    def connect
      @sock = TCPSocket.new("ns-server.epita.fr", 4242)
      if (!@sock)
        return false
      end
      buf = sock_get
      cmd, socket_num, md5_hash, client_ip, client_port, server_timestamp = buf.split
      server_timestamp_diff = Time.now.to_i - server_timestamp.to_i
      @connection_values[:md5_hash] = md5_hash
      @connection_values[:client_ip] = client_ip
      @connection_values[:client_port] = client_port
      @connection_values[:login] = @config[:login]
      @connection_values[:socks_password] = @config[:socks_password]
      @connection_values[:unix_password] = @config[:unix_password]
      @connection_values[:state] = @config[:state]
      @connection_values[:location] = @config[:location]
      @connection_values[:user_group] = @config[:user_group]
      @connection_values[:system] = @config[:system]
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

      if (@config[:unix_password].length > 0)
        sock_send(Message.kerberos_authentication(@connection_values))
      else
        sock_send(Message.standard_authentication(@connection_values))
      end

      if (sock_get().split(' ')[1] == "002")
        @authentificated = true
        sock_send("user_cmd attach")
        Message.set_state(@config[:state], get_server_timestamp)
      else
        return false
      end
      return true
    end

    def disconnect
      sock_send(Message.deconnexion)
      @authenticated = false
      sock_close
      @connected = false
    end

    def sock_send(string)
      if (@sock)
        @sock.puts string
      end
    end

    def sock_get
      if (@sock)
        response = @sock.gets.to_s.chomp
        return response
      end
    end

    def sock_close
      if (@sock)
        @sock.close
        @sock = nil
      end
    end

    def get_server_timestamp
      Time.now.to_i - @connection_values[:timestamp_diff].to_i
    end
  end
end

