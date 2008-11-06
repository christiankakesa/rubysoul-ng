=begin
  Made by Christian KAKESA etna_2008(paris) <christian.kakesa@gmail.com>
=end

begin
  require 'open-uri'
  require 'rs_config'
  require 'singleton'
rescue LoadError
  puts "Error: #{$!}"
  exit
end

class RsContact
  include Singleton

  attr_accessor :contacts, :url_photo

  def initialize
    @contacts = YAML::load_file(RsConfig::CONTACTS_FILENAME)
    if not @contacts.is_a?(Hash)
      @contacts = Hash.new
    end
    @url_photo = RsConfig::CONTACTS_PHOTO_URL #--- | chck if are in PIE for locale url : http://intra/photo.php?login=
    get_users_photo()
  end

  def load_contacts
    @contacts = YAML::load_file(RsConfig::CONTACTS_FILENAME)
  end
  #--- Add login to the YML contact file.
  def add(login, save_it = false)
    if not (@contacts.include?(login.to_sym))
      @contacts[login.to_sym] = Hash.new
      save() if save_it
    end
  end

  #--- Remove contact to the YML file.
  def remove(login, save_it = false)
    @contacts = @contacts.delete_if do |key, value|
      key.eql?(login.to_sym)
    end
    save() if save_it
  end

  #--- Save contact hash table to the YAML file
  def save
    c = Hash.new
    @contacts.each do |k, v|
      c[k.to_sym] = Hash.new
    end
    File.open(RsConfig::CONTACTS_FILENAME, "wb") do |file|
      file.puts '#--- ! RubySoulNG contacts file'
      file.puts c.to_yaml
      file.close()
    end
  end

  def get_users_list
    @user_list = String.new
    @contacts.each do |k, v|
      @user_list += k.to_s + ","
    end
    @user_list = @user_list.slice(0, @user_list.length - 1)
    return @user_list
  end

  def get_users_photo
    dest_dir = RsConfig::CONTACTS_PHOTO_DIR
    if not (FileTest.directory?(dest_dir))
      Dir.mkdir(dest_dir, 755)
    end
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
        begin
          hh = open(@url_photo + k.to_s, "rb")
        rescue
          puts "Error: #{$!}"
        end
        if (hh)
          h = File.open(dest_dir + File::SEPARATOR + k.to_s, "wb")
          if (h)
            h.write(hh.read)
            h.close
          end
          hh.close
        end
      end
    end
  end
end

