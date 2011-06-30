=begin
	Made by Christian KAKESA etna_2008(paris) <christian.kakesa@gmail.com>
=end

begin
	require 'open-uri'
	require 'singleton'
	require 'rs_infobox'
rescue LoadError
	puts "Error: #{$!}"; exit!;
end

class RsContact
	include Singleton

	attr_accessor :contacts, :url_photo

	def initialize()
		@rs_config = RsConfig::instance()
		@url_photo = @rs_config.contacts_photo_url #--- | chck if are in PIE for locale url : http://intra/photo.php?login=
		load_contacts()
	end

	def load_contacts
		@contacts = YAML::load_file(@rs_config.contacts_filename)
		if not @contacts.is_a?(Hash)
			@contacts = Hash.new
		end
	end
	#--- Add login to the YML contact file.
	def add(login, save_it = false)
		if not (@contacts.include?(login.to_sym))
			total_length = get_users_list().to_s.length + login.to_s.length
			if total_length <= 1022 # 1022 is limit of netsoul watch_log_user command
				@contacts[login.to_sym] = Hash.new
				save() if save_it
			else
				raise(StandardError, "NetSoul server is not able to manage more contacts status for you.\nRemove one or more contacts before adding another.\nThis limitation is made by Netsoul server, sorry.")
			end
		end
	end

	#--- Remove contact to the YML file.
	def remove(login, save_it = false)
		@contacts.delete(login.to_s.to_sym)
		if FileTest.exist?(@rs_config.contacts_photo_dir+File::SEPARATOR+login.to_s)
			begin
				File.delete(@rs_config.contacts_photo_dir+File::SEPARATOR+login.to_s)
			rescue
				RsInfobox.new(@parent_win, "#{$!}", "warning")
			end
		end
		save() if save_it
	end

	#--- Save contact hash table to the YAML file
	def save
		c = Hash.new
		if @contacts.length > 0
			@contacts.keys.uniq.each do |l|
				c[l.to_s.to_sym] = Hash.new
			end
		end
		File.open(@rs_config.contacts_filename, "wb") do |file|
			file.puts '#--- ! RubySoulNG contacts file'
			file.puts c.to_yaml
		end
	end

	def get_users_list
		user_list = String.new
		@contacts.each do |k, v|
			user_list += k.to_s + ","
		end
		user_list = user_list.slice(0, user_list.length - 1)
		return user_list
	end

	def get_users_photo
		dest_dir = @rs_config.contacts_photo_dir
		files = Array.new
		exclude_dir = [".", ".."]
		lf = Dir.open(dest_dir)
		liste = lf.sort - exclude_dir
		lf.close
		liste.each do |f|
			if (File.ftype(dest_dir + File::SEPARATOR + f) == "file")
				files << f.to_s
			end
		end
		@contacts.each do |k, v|
			if not (files.include?(k.to_s))
				get_user_photo(k)
			end
		end
	end

	def get_user_photo(login)
	  begin
			hh = open(@url_photo + login.to_s, "rb")
		rescue
			$log.warn("Error: #{$!}")
		end
		if (hh)
			h = File.open(@rs_config.contacts_photo_dir + File::SEPARATOR + login.to_s, "wb")
			if (h)
				h.write(hh.read)
				h.close
			end
			hh.close
		end
	end
end

