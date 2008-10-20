=begin
  Developpers  : Christian KAKESA etna_2008(paris) <christian.kakesa@gmail.com>
=end

begin
	require 'rs_config'
rescue LoadError
	puts "Error: #{$!}"
	exit
end

class RsContact
  attr_accessor :contacts, :user_list, :url_photo
  
  def initialize
    @user_list = String.new
    @contacts = YAML::load(File.open('data/contacts.yml', 'r+b'))
    if not @contacts
      @contacts = Hash.new
    end
    @url_photo = 'http://intra.epitech.eu/intra/photo.php?login='
  end
  #--- Add login to the YML contact file.
  def add(login)
    if not (@contacts.include?(login.to_s))
      @contacts[login.to_s] = Hash.new
    end
    
  end
  #--- Modify contact to the YML contact file.
  def modify(login)
  
  end
  #--- Remove contact to the YML file.
  def remove(login)
  
  end
  #--- Save contact hash table to the YAML file
  def save
    file = File.open('data/contacts.yml', "wb")
    file.puts '#--- ! User contact list'
    file.puts(@contacts.to_yaml)
    file.close
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
    dest_dir = File.dirname(__FILE__) + File::SEPARATOR + "images" + File::SEPARATOR + "contacts" + File::SEPARATOR
    if not (FileTest.directory?(dest_dir))
      Dir.mkdir(dest_dir, 755)
    end
    files = Array.new
    exclude_dir = [".", ".."]
    lf = Dir.open(dest_dir)
    liste = lf.sort - exclude_dir
    lf.close
    liste.each do |f|
      if (File.ftype(dest_dir + f) == "file")
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
          h = File.open(dest_dir + k.to_s, "wb")
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
