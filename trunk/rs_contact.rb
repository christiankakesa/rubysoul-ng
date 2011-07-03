=begin
	Made by Christian KAKESA etna_2008(paris) <christian.kakesa@gmail.com>
=end

begin
  require 'net/http'
  require 'uri'
  require 'singleton'
  require 'rs_infobox'
rescue LoadError
  puts "Error: #{$!}"; exit!;
end

class ContentTypeError < RuntimeError; end

class RsContact
  include Singleton

  attr_accessor :contacts

  def initialize()
    @rs_config = RsConfig::instance()
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
        $log.debug("Retrieving #{k.to_s} user photo")
        get_user_photo(k)
      end
    end
  end

  def get_user_photo(login)
    begin
      # Proxy settings if available
      p_host = nil
      p_port = nil
      p_user = nil
      p_password = nil
      if @rs_config.conf[:proxy_http_use]
        p_host = @rs_config.conf[:proxy_http_host]
        p_port = @rs_config.conf[:proxy_http_port]
        if @rs_config.conf[:proxy_username].to_s.length > 0
          p_user =  @rs_config.conf[:proxy_username]
        end
        if @rs_config.conf[:proxy_password].to_s.length > 0
          p_password =  @rs_config.conf[:proxy_password]
        end
      elsif ENV.include?('http_proxy')
        uri = URI.parse(ENV['http_proxy'])
        p_host = uri.host if uri.host
        p_port = uri.port if uri.port
        p_user, p_password = uri.userinfo.split(/:/) if uri.userinfo
      end
      $log.debug("Contacts photo url : %s - Contacts photo ural_path : %s" % [@rs_config.contacts_photo_url, @rs_config.contacts_photo_url_path])
      Net::HTTP.start(@rs_config.contacts_photo_url, nil, p_host, p_port, p_user, p_password) do |http|
        resp = http.get('/' + @rs_config.contacts_photo_url_path + login.to_s, {"User-Agent" =>
                          "#{RsConfig::APP_USER_AGENT}"})
        if ['image/jpeg', 'image/png', 'image/gif', 'image/jpg'].include?(resp["Content-Type"])
          $log.debug("Writing #{@rs_config.contacts_photo_dir + File::SEPARATOR + login.to_s} user photo file. Content-Type : %s" % [resp["Content-Type"]])
          File.open(@rs_config.contacts_photo_dir + File::SEPARATOR + login.to_s, "wb") do |file|
            file.write(resp.body)
          end
        else
          raise ContentTypeError, "User photo don't have a good content type. Retry to retrieve it : %s" % [resp["Content-Type"]]
        end
      end
    rescue ContentTypeError => err
      $log.warn("#{err}")
      sleep(1.0)
      retry
    rescue => err
      $log.warn("#{err}")
      raise
    end
  end
end

