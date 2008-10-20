=begin
  Developpers  : Christian KAKESA etna_2008(paris) <christian.kakesa@gmail.com>
=end

begin
	require 'uri'
	require 'digest/md5'
rescue LoadError
	puts "Error: #{$!}"
end

module NetSoul
class Message
	def self.standard_authentication(connection_values)
		auth_string = Digest::MD5.hexdigest('%s-%s/%s%s'%[	connection_values[:md5_hash],
									connection_values[:client_ip],
									connection_values[:client_port],
									connection_values[:password]	])
		return 'ext_user_log %s %s %s %s'%[	connection_values[:login],
							auth_string,
							Location::get(connection_values[:client_ip]),
							ns_escape(connection_values[:user_data])]
	end

	def self.kerberos_authentication(connection_values)

	end

	def self.send_message(user, msg)
		return 'user_cmd msg_user %s msg %s'%[user, ns_escape(msg)]
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

	def self.who_user(user)
		return 'user_cmd who %s'%[user]
	end

	def self.watch_users(user_list)
		return 'user_cmd watch_log_user {%s}'%[user_list]
	end

	def self.watch_user(user)
		return 'user_cmd watch_log_user %s'%[user]
	end

	def self.set_state(state, timestamp)
		return 'user_cmd state %s:%s'%[state, timestamp]
	end

	def self.set_user_data(data)
		return 'user_cmd user_data %s'%[ns_escape(data)]
	end

	def self.ping
		return "ping"
	end

	def self.exit
		return "exit"
	end

	def self.ns_escape(str)
		str = URI.escape(str)
		URI.escape(str, "\ :'@~\[\]&()=*$!;,\+\/\?")
	end
end
end

