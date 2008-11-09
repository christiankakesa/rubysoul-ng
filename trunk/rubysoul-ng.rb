#!/usr/bin/ruby -w
=begin
  Made by Christian KAKESA etna_2008(paris) <christian.kakesa@gmail.com>

  TODO: implementer une function at_exit/deconnexion pour quitter proprement netsoul si on ferme l'aaplication'
=end

$KCODE = 'u'

begin
  require 'libglade2'
  require 'thread'
  require 'lib/netsoul'
  require 'rs_config'
  require 'rs_contact'
  require 'rs_infobox'
  require 'rs_dialog'
rescue LoadError
  puts "Error: #{$!}"
  exit
end

class RubySoulNG
  include GetText

  attr :glade

  def initialize
    @domain = RsConfig::APP_NAME
    bindtextdomain(@domain, nil, nil, "UTF-8")
    @glade = GladeXML.new(
    "#{RsConfig::APP_DIR+File::SEPARATOR}rubysoul-ng_win.glade",
    nil,
    @domain,
    nil,
    GladeXML::FILE) do |handler|
      method(handler)
    end
    @rsng_win = @glade['RubySoulNG']
    @rsng_tb_connect = @glade['tb_connect']
    @rsng_user_view = @glade['user_view']
    @rsng_state_box = @glade['state_box']
    @contact_win = @glade['contact']
    @contact_add_entry = @glade['contact_add_entry']
    @contact_add_btn = @glade['contact_add_btn']
    @preferences_win = @glade['preferences']
    @preferences_nbook = @glade['prefs']
    @account_login_entry = @glade['account_login_entry']
    @account_socks_password_entry = @glade['account_socks_password_entry']
    @account_unix_password_entry = @glade['account_unix_password_entry']
    @aboutdialog = @glade['aboutdialog']
    @user_dialogs = Hash.new

    @rs_config = RsConfig::instance()
    @rs_contact = RsContact::instance()

    @mutex_send_msg = Mutex.new

    rsng_user_view_init()
    rsng_state_box_init()
    preferences_account_init()
    preferences_account_load_config(@rs_config.conf)

    @ns = NetSoul::NetSoul::instance()
    if @rs_config.conf[:connection_at_startup]
      connection()
    end
  end

  def connection
    if @rs_config.conf[:login].to_s.length == 0
      @preferences_win.show_all()
      @preferences_nbook.set_page(0)
      @preferences_win.set_focus(@account_login_entry)
      return false
    elsif @rs_config.conf[:socks_password].to_s.length == 0 && @rs_config.conf[:connection_type].to_s.eql?("md5")
      @preferences_win.show_all()
      @preferences_nbook.set_page(0)
      @preferences_win.set_focus(@account_socks_password_entry)
      return false
    elsif @rs_config.conf[:unix_password].to_s.length == 0 && @rs_config.conf[:connection_type].to_s.eql?("krb5")
      @preferences_win.show_all()
      @preferences_nbook.set_page(0)
      @preferences_win.set_focus(@account_unix_password_entry)
      return false
    end
    if @ns.connect()
      @rsng_tb_connect.set_stock_id(Gtk::Stock::DISCONNECT)
      @rsng_tb_connect.set_label("Disconnection")
      @rsng_user_view.set_sensitive(true)
      @parse_thread = Thread.new do
        loop do
          parse_cmd() if @ns.authenticated
        end
      end
      rsng_state_box_update()
      send_cmd( NetSoul::Message.who_users(@rs_contact.get_users_list()) )
      send_cmd( NetSoul::Message.watch_users(@rs_contact.get_users_list()) )
      return true
    else
      RsInfobox.new(@rsng_win, "Impossible to connect to the NetSoul server", "warning", false)
      return false
    end
  end
  def disconnection
    @ns.disconnect()
    @parse_thread.kill!
    @rsng_tb_connect.set_stock_id(Gtk::Stock::CONNECT)
    @rsng_tb_connect.set_label("Connection")
    @user_model.clear()
    @rs_contact.contacts.each do |key, value|
      h = @user_model.append(nil)
      h.set_value(0, Gdk::Pixbuf.new(RsConfig::ICON_DISCONNECT, 24, 24))
      h.set_value(1, %Q[<span weight="bold" size="large">#{key.to_s}</span>])
      if (File.exist?("#{RsConfig::CONTACTS_PHOTO_DIR + File::SEPARATOR + key.to_s}"))
        h.set_value(2, Gdk::Pixbuf.new("#{RsConfig::CONTACTS_PHOTO_DIR + File::SEPARATOR + key.to_s}", 32, 32))
      else
        h.set_value(2, Gdk::Pixbuf.new("#{RsConfig::CONTACTS_PHOTO_DIR + File::SEPARATOR}login_l", 32, 32))
      end
      h.set_value(3, key.to_s)
      h.set_value(4, "num_session")
      h.set_value(5, "status")
      h.set_value(6, "user_data")
      h.set_value(7, "location")
    end
    @rsng_user_view.set_sensitive(false)
    @rsng_state_box.set_sensitive(false)
    @rs_contact.load_contacts()
  end

  def parse_cmd
    begin
      buff = @ns.sock_get().to_s
    rescue
      disconnection()
      return
    end
    if not (buff.length > 0)
      return
    end
    puts buff.to_s
    case buff.split(' ')[0]
    when "ping"
      ping()
    when "rep"
      rep(buff)
    when "user_cmd"
      user_cmd(buff)
    else
      if buff.split(' ').length == 12 # list_user, for user location update
        socket = buff.split(' ')[0]
        login = buff.split(' ')[1]
        status = buff.split(' ')[10].split(':')[0]
        user_data = URI.unescape(buff.split(' ')[11])
        location = URI.unescape(buff.split(' ')[8])
        if not @rs_contact.contacts[login.to_sym].is_a?(Hash)
          @rs_contact.contacts[login.to_sym] = Hash.new
        end
        if not (@rs_contact.contacts[login.to_sym].include?(:connections))
          @rs_contact.contacts[login.to_sym][:connections] = Hash.new
        end
        if not (@rs_contact.contacts[login.to_sym][:connections].include?(socket.to_i))
          @rs_contact.contacts[login.to_sym][:connections][socket.to_i] = Hash.new
        end
        @rs_contact.contacts[login.to_sym][:connections][socket.to_i][:num_session] = socket.to_s
        @rs_contact.contacts[login.to_sym][:connections][socket.to_i][:status] = status.to_s
        @rs_contact.contacts[login.to_sym][:connections][socket.to_i][:user_data] = user_data.to_s
        @rs_contact.contacts[login.to_sym][:connections][socket.to_i][:location] = location.to_s
        @user_model.each do |model,path,iter|
          if (iter[4].to_s == socket.to_s)
            iter.set_value(0, Gdk::Pixbuf.new(get_status_icon(status.to_s), 24, 24))
            limit_location = 15
            my_location = location.to_s.slice(0, limit_location.to_i)
            if location.to_s.length > limit_location.to_i
              my_location += "..."
            end
            if @rs_contact.contacts[login.to_sym][:connections].length == 1
              iter.set_value(1, %Q[<span weight="bold" size="large">#{login.to_s}</span>])
              if (File.exist?("#{RsConfig::CONTACTS_PHOTO_DIR + File::SEPARATOR + login.to_s}"))
                iter.set_value(2, Gdk::Pixbuf.new("#{RsConfig::CONTACTS_PHOTO_DIR + File::SEPARATOR + login.to_s}", 32, 32))
              else
                iter.set_value(2, Gdk::Pixbuf.new("#{RsConfig::CONTACTS_PHOTO_DIR + File::SEPARATOR}login_l", 32, 32))
              end
            else
              iter.set_value(1, %Q[<span weight="normal" size="x-small"> - #{my_location.to_s} on #{user_data.to_s.slice(0, 23)}</span>])
              iter.set_value(2, nil)
            end
            iter.set_value(3, login.to_s)
            iter.set_value(4, socket.to_s)
            iter.set_value(5, status.to_s)
            iter.set_value(6, user_data)
            iter.set_value(7, location)
          end
        end
      else
        #puts "Unknown command " + buff
      end
    end
  end

  def send_cmd(msg)
    @mutex_send_msg.synchronize do
      @ns.sock_send(msg)
    end
  end

  def ping
    send_cmd(NetSoul::Message.ping())
    return true
  end

  def rep(cmd)
    msg_num= cmd.split(' ')[1]
    case msg_num.to_s
    when "001"
      #Command unknown
    when "002"
      #Nothing to do, all is right
      #puts '[REP_OK] %s:%s'%[msg_num.to_s, msg]
      return true
    when "003"
      #bad number of arguments
    when "033"
      #Login or password incorrect
      RsInfobox.new(self, "Login or password incorrect", "warning")
    when "140"
      RsInfobox.new(self, "User identification failed", "warning")
    else
      # puts "Something is wrong in \"REP\" command response..."
      # puts '[Response not Yet implemented] %s'%[cmd.to_s]
    end
    disconnection()
    return false
  end

  def user_cmd(usercmd)
    cmd, user	= NetSoul::Message.trim(usercmd.split('|')[0]).split(' ')
    response	= NetSoul::Message.trim(usercmd.split('|')[1])
    sub_cmd	= NetSoul::Message.trim(user.split(':')[1])
    case sub_cmd.to_s
    when "mail"
      sender, subject = response.split(' ')[2..3]
      msg = "Vous avez reçu un email !!!\nDe: " + URI.unescape(sender) + "\nSujet: " + URI.unescape(subject)[1..-2]
      RsInfobox.new(self, msg, "info", false)
      return true
    when "host"
      sender = response.split(' ')[2]
      msg = "Appel en en cours... !!!\nDe: " + URI.unescape(sender)[1..-1]
      RsInfobox.new(self, msg, "info", false)
      return true
    when "user"
      get_user_response(cmd, user, response)
      return true
    else
      puts "[user_cmd] : " + usercmd + " - This command is not parsed, please contacte the developper"
      return false
    end
  end

  def get_user_response(cmd, user, response)
    sender = user.split(":")[3].split('@')[0]
    sub_cmd = response.split(' ')[0]
    case sub_cmd
    when "dotnetSoul_UserTyping", "typing_start"
      #| dotnetSoul_UserTyping null dst=kakesa_c
      #puts "[#{sub_cmd.to_s}] : " + sender + " - " + sub_cmd + " - " + response
    when "dotnetSoul_UserCancelledTyping", "typing_end"
      #| dotnetSoul_UserCancelledTyping null dst=kakesa_c
      #puts "[#{sub_cmd.to_s}] : " + sender + " - " + sub_cmd + " - " + response
    when "msg"
      msg = URI.unescape(response.split(' ')[1])
      socket = response.split(' ')[1]
      login = sender.to_s

      if not @user_dialogs.include?(login.to_sym)
        @user_dialogs[login.to_sym] = RsDialog.new(login.to_s, socket)
        @user_dialogs[login.to_sym].signal_connect("delete-event") do |widget, event|
          @user_dialogs[login.to_sym].hide_all()
        end
      end
      @user_dialogs[login.to_sym].show_all()
      @user_dialogs[login.to_sym].receive_msg(login.to_s, msg)
      puts "[msg] : " + sender + " - " + sub_cmd + " - " + msg + " - " + response
    when "who"
      if not response.match(/cmd end$/)
        socket = response.split(' ')[1]
        login = response.split(' ')[2]
        status = response.split(' ')[11].split(':')[0]
        user_data = URI.unescape(response.split(' ')[12])
        location = URI.unescape(response.split(' ')[9])
        if not @rs_contact.contacts[login.to_sym].is_a?(Hash)
          @rs_contact.contacts[login.to_sym] = Hash.new
        end
        if not (@rs_contact.contacts[login.to_sym].include?(:connections))
          @rs_contact.contacts[login.to_sym][:connections] = Hash.new
        end
        if not (@rs_contact.contacts[login.to_sym][:connections].include?(socket.to_i))
          @rs_contact.contacts[login.to_sym][:connections][socket.to_i] = Hash.new
        end
        @rs_contact.contacts[login.to_sym][:connections][socket.to_i][:num_session] = socket.to_s
        @rs_contact.contacts[login.to_sym][:connections][socket.to_i][:status] = status.to_s
        @rs_contact.contacts[login.to_sym][:connections][socket.to_i][:user_data] = user_data.to_s
        @rs_contact.contacts[login.to_sym][:connections][socket.to_i][:location] = location.to_s
      else
        rsng_user_view_update()
      end
      #puts "[who] : " + sender + " - " + sub_cmd + " - " + response
    when "state"
      #send_cmd( NetSoul::Message.list_users(login.to_s) ) # update user_data, location
      socket = user.split(':')[0].to_s
      @user_model.each do |model,path,iter|
        if (iter[4].to_s == socket.to_s)
          iter.set_value(0, Gdk::Pixbuf.new(get_status_icon(response.split(' ')[1].split(':')[0]), 24, 24))
        end
      end
      #puts "[state] : " + sender + " - " + sub_cmd + " - " + response
    when "login"
      login = sender.to_s
      socket = user.split(':')[0]
      if not @rs_contact.contacts[login.to_sym].is_a?(Hash)
        @rs_contact.contacts[login.to_sym] = Hash.new
      end
      if not (@rs_contact.contacts[login.to_sym].include?(:connections))
        @rs_contact.contacts[login.to_sym][:connections] = Hash.new
      end
      if not (@rs_contact.contacts[login.to_sym][:connections].include?(socket.to_i))
        @rs_contact.contacts[login.to_sym][:connections][socket.to_i] = Hash.new
      end
      @rs_contact.contacts[login.to_sym][:connections][socket.to_i][:num_session] = socket.to_s
      @rs_contact.contacts[login.to_sym][:connections][socket.to_i][:status] = "login"
      @rs_contact.contacts[login.to_sym][:connections][socket.to_i][:user_data] = "user_data"
      @rs_contact.contacts[login.to_sym][:connections][socket.to_i][:location] = "location"
      if @rs_contact.contacts[login.to_sym][:connections].length == 1
        @user_model.each do |model,path,iter|
          @user_model.remove(iter) if (iter[3].to_s == login.to_s)
        end
        @rs_contact.contacts[login.to_sym][:connections].each do |key, val|
          iter = @user_model.prepend(nil)
          iter.set_value(0, Gdk::Pixbuf.new(get_status_icon(val[:status]), 24, 24))
          iter.set_value(1, %Q[<span weight="bold" size="large">#{login.to_s}</span>])
          if (File.exist?("#{RsConfig::CONTACTS_PHOTO_DIR + File::SEPARATOR + login.to_s}"))
            iter.set_value(2, Gdk::Pixbuf.new("#{RsConfig::CONTACTS_PHOTO_DIR + File::SEPARATOR + login.to_s}", 32, 32))
          else
            iter.set_value(2, Gdk::Pixbuf.new("#{RsConfig::CONTACTS_PHOTO_DIR + File::SEPARATOR}login_l", 32, 32))
          end
          iter.set_value(3, login.to_s)
          iter.set_value(4, key.to_s)
          iter.set_value(5, val[:status].to_s)
          iter.set_value(6, "user_data")
          iter.set_value(7, "location")
        end
      elsif @rs_contact.contacts[login.to_sym][:connections].length == 2
        puts @rs_contact.contacts.to_yaml.to_s
        @user_model.each do |model,path,iter|
          if (iter[3].to_s == login.to_s)
            iter.set_value(0, Gdk::Pixbuf.new(RsConfig::ICON_MULTICONNECT, 24, 24))
            iter.set_value(1, %Q[<span weight="bold" size="large">#{login.to_s}</span>])
            if (File.exist?("#{RsConfig::CONTACTS_PHOTO_DIR + File::SEPARATOR + login.to_s}"))
              iter.set_value(2, Gdk::Pixbuf.new("#{RsConfig::CONTACTS_PHOTO_DIR + File::SEPARATOR + login.to_s}", 32, 32))
            else
              iter.set_value(2, Gdk::Pixbuf.new("#{RsConfig::CONTACTS_PHOTO_DIR + File::SEPARATOR}login_l", 32, 32))
            end
            iter.set_value(3, login.to_s)
            iter.set_value(4, "num_session")
            iter.set_value(5, "status")
            iter.set_value(6, "user_data")
            iter.set_value(7, "location")
            @rs_contact.contacts[login.to_sym][:connections].each do |k, v|
              it = @user_model.append(iter)
              it.set_value(0, Gdk::Pixbuf.new(get_status_icon(v[:status].to_s), 24, 24))
              limit_location = 15
              my_location = v[:location].to_s.slice(0, limit_location.to_i)
              if v[:location].to_s.length > limit_location.to_i
                my_location += "..."
              end
              it.set_value(1, %Q[<span weight="normal" size="x-small"> - #{my_location.to_s} on #{v[:user_data].to_s.slice(0, 23)}</span>])
              it.set_value(2, nil)
              it.set_value(3, login.to_s)
              it.set_value(4, k.to_s)
              it.set_value(5, v[:status].to_s)
              it.set_value(6, v[:user_data].to_s)
              it.set_value(7, v[:location].to_s)
              it.set_value(8, "children")
            end
            break # because sub element contening login too and always cycling
          end
        end
      elsif @rs_contact.contacts[login.to_sym][:connections].length > 2
        @user_model.each do |model,path,iter|
          if (iter[3].to_s == login.to_s && iter[4].to_s == socket.to_s)
            iter.set_value(0, Gdk::Pixbuf.new(get_status_icon(status.to_s), 24, 24))
            iter.set_value(2, nil)
            iter.set_value(3, login.to_s)
            iter.set_value(4, socket.to_s)
            iter.set_value(5, status.to_s)
            iter.set_value(6, "user_data")
            iter.set_value(7, "location")
            iter.set_value(8, "children")
          elsif (iter[3].to_s == login.to_s && iter[4].to_s == "num_session")
            it = @user_model.append(iter)
            it.set_value(0, Gdk::Pixbuf.new(get_status_icon(status.to_s), 24, 24))
            it.set_value(2, nil)
            it.set_value(3, login.to_s)
            it.set_value(4, socket.to_s)
            it.set_value(5, status.to_s)
            it.set_value(6, "user_data")
            it.set_value(7, "location")
            it.set_value(8, "children")
          end
        end
      end
      send_cmd( NetSoul::Message.list_users(login.to_s) )
      #puts "[login] : " + sender + " - " + sub_cmd
    when "logout"
      login = sender.to_s
      socket = user.split(':')[0]
      if @rs_contact.contacts.include?(login.to_sym) && @rs_contact.contacts[login.to_sym].include?(:connections) && @rs_contact.contacts[login.to_sym][:connections].include?(socket.to_i)
        @rs_contact.contacts[login.to_sym][:connections].delete(socket.to_i)
        if @rs_contact.contacts[login.to_sym][:connections].length == 0 # delete and put at bottom
          @user_model.each do |model,path,iter|
            @user_model.remove(iter) if (iter[4].to_s == socket.to_s)
          end
          iter = @user_model.append(nil)
          iter.set_value(0, Gdk::Pixbuf.new(RsConfig::ICON_DISCONNECT, 24, 24))
          iter.set_value(1, %Q[<span weight="bold" size="large">#{login.to_s}</span>])
          if (File.exist?("#{RsConfig::CONTACTS_PHOTO_DIR + File::SEPARATOR + login.to_s}"))
            iter.set_value(2, Gdk::Pixbuf.new("#{RsConfig::CONTACTS_PHOTO_DIR + File::SEPARATOR + login.to_s}", 32, 32))
          else
            iter.set_value(2, Gdk::Pixbuf.new("#{RsConfig::CONTACTS_PHOTO_DIR + File::SEPARATOR}login_l", 32, 32))
          end
          iter.set_value(3, login.to_s)
          iter.set_value(4, "num_session")
          iter.set_value(5, "status")
          iter.set_value(6, "user_data")
          iter.set_value(7, "location")
        elsif @rs_contact.contacts[login.to_sym][:connections].length == 1 # last sub element need to be root element
          @user_model.each do |model,path,iter|
            @user_model.remove(iter) if (iter[4].to_s == socket.to_s)
          end
          @user_model.each do |model,path,iter|
            @user_model.remove(iter) if (iter[3].to_s == login.to_s)
          end
          @rs_contact.contacts[login.to_sym][:connections].each do |key, val|
            iter = @user_model.prepend(nil)
            iter.set_value(0, Gdk::Pixbuf.new(get_status_icon(val[:status].to_s), 24, 24))
            iter.set_value(1, %Q[<span weight="bold" size="large">#{login.to_s}</span>])
            if (File.exist?("#{RsConfig::CONTACTS_PHOTO_DIR + File::SEPARATOR + login.to_s}"))
              iter.set_value(2, Gdk::Pixbuf.new("#{RsConfig::CONTACTS_PHOTO_DIR + File::SEPARATOR + login.to_s}", 32, 32))
            else
              iter.set_value(2, Gdk::Pixbuf.new("#{RsConfig::CONTACTS_PHOTO_DIR + File::SEPARATOR}login_l", 32, 32))
            end
            iter.set_value(3, login.to_s)
            iter.set_value(4, key.to_s)
            iter.set_value(5, val[:status].to_s)
            iter.set_value(6, val[:user_data].to_s)
            iter.set_value(7, val[:location].to_s)
          end
        elsif @rs_contact.contacts[login.to_sym][:connections].length >= 2 # just delete thirdth or more element
          @user_model.each do |model,path,iter|
            @user_model.remove(iter) if (iter[4].to_s == socket.to_s)
          end
        end
        #puts "[logout] : " + sender + " - " + sub_cmd
      else
        #puts "[unknown sub command] : " + sender + " - " + sub_cmd
        return false
      end
      return true
    end
  end
  #--- | Main window
  def on_RubySoulNG_delete_event(widget, event)
    begin
      disconnection()
    rescue
    ensure
      Gtk.main_quit()
    end
  end

  def on_tb_connect_clicked(widget)
    begin
      if @ns.authenticated
        disconnection()
      else
        connection()
      end
    rescue
      RsInfobox.new(@rsng_win, "#{$!}", "error", false)
    end
  end
  def on_tb_contact_clicked(widget)
    @contact_win.show_all()
  end
  def on_tb_preferences_clicked(widget)
    preferences_account_load_config(@rs_config.conf)
    @preferences_win.show_all()
    @preferences_nbook.set_page(0)
  end
  def on_tb_about_clicked(widget)
    @aboutdialog.show_all()
    @aboutdialog.run()
    @aboutdialog.hide_all()
  end
  def rsng_user_view_init
    #--- | ICON_STATE, HTML Login, PHOTO, Login, {sublist} SessionNum, State, UserData, Location, UserAgent
    @user_model = Gtk::TreeStore.new(Gdk::Pixbuf, String, Gdk::Pixbuf, String, String, String, String, String, String)
    #@user_model.set_sort_column_id(1)
    @rsng_user_view.set_model(@user_model)
    renderer = Gtk::CellRendererPixbuf.new
    renderer.set_xalign(0.5)
    renderer.set_yalign(0.5)
    column = Gtk::TreeViewColumn.new("Status", renderer, :pixbuf => 0)
    @rsng_user_view.append_column(column)
    renderer = Gtk::CellRendererText.new
    renderer.set_alignment(Pango::ALIGN_LEFT)
    column = Gtk::TreeViewColumn.new("Login / Location", renderer, :markup => 1)
    @rsng_user_view.append_column(column)
    renderer = Gtk::CellRendererPixbuf.new
    renderer.set_xalign(1.0)
    renderer.set_yalign(0.5)
    column = Gtk::TreeViewColumn.new("Photo", renderer, :pixbuf => 2)
    @rsng_user_view.append_column(column)
    @rs_contact.contacts.each do |key, value|
      h = @user_model.append(nil)
      h.set_value(0, Gdk::Pixbuf.new(RsConfig::ICON_DISCONNECT, 24, 24))
      h.set_value(1, %Q[<span weight="bold" size="large">#{key.to_s}</span>])
      if (File.exist?("#{RsConfig::CONTACTS_PHOTO_DIR + File::SEPARATOR + key.to_s}"))
        h.set_value(2, Gdk::Pixbuf.new("#{RsConfig::CONTACTS_PHOTO_DIR + File::SEPARATOR + key.to_s}", 32, 32))
      else
        h.set_value(2, Gdk::Pixbuf.new("#{RsConfig::CONTACTS_PHOTO_DIR + File::SEPARATOR}login_l", 32, 32))
      end
      h.set_value(3, key.to_s)
      h.set_value(4, "num_session")
      h.set_value(5, "status")
      h.set_value(6, "user_data")
      h.set_value(7, "location")
    end
    @rsng_user_view.signal_connect("row-activated") do |view, path, column|
      if (	view.model.get_iter(path)[5].to_s.eql?("actif") or view.model.get_iter(path)[5].to_s.eql?("away") or view.model.get_iter(path)[5].to_s.eql?("busy") or view.model.get_iter(path)[5].to_s.eql?("idle") or view.model.get_iter(path)[5].to_s.eql?("lock")	)
        login = view.model.get_iter(path)[3]
        num_session = view.model.get_iter(path)[4]
        state = view.model.get_iter(path)[5]
        user_data = view.model.get_iter(path)[6]
        if not @user_dialogs.include?(login.to_sym)
          @user_dialogs[login.to_sym] = RsDialog.new(login, num_session)
          @user_dialogs[login.to_sym].signal_connect("delete-event") do |widget, event|
            @user_dialogs[login.to_sym].hide_all()
          end
        end
        @user_dialogs[login.to_sym].show_all()
      end
    end
    @rsng_user_view_menu_delete =  Gtk::MenuItem.new("Delete")
    @rsng_user_view_menu_delete.signal_connect("activate") do |widget, event|
      iter = @rsng_user_view.selection.selected
      if iter
        if iter[8].to_s != "children"
          login = iter[3]
          @user_model.remove(iter) && @rs_contact.remove(login.to_s, true)
        end
      end
    end
    @rsng_user_view_menu = Gtk::Menu.new
    @rsng_user_view_menu.append(@rsng_user_view_menu_delete)
    @rsng_user_view.signal_connect("button-press-event") do |widget, event|
      if event.kind_of? Gdk::EventButton
        if (event.button.to_i == 3)
          path, column, x, y = @rsng_user_view.get_path_at_pos(event.x, event.y)
          iter = @user_model.get_iter(path)
          if (iter[8].to_s != "children" && iter == @rsng_user_view.selection.selected)
            @rsng_user_view_menu.popup(nil, nil, event.button, event.time) do |menu, x, y, push_in|
              [x, y, push_in]
            end
            @rsng_user_view_menu.show_all()
          end
        end
      end
    end
  end
  def rsng_user_view_update
    @user_model.clear()
    @rs_contact.contacts.each do |key, val|
      login = key
      if not @rs_contact.contacts[login.to_sym].include?(:connections)
        iter = @user_model.append(nil)
        iter.set_value(0, Gdk::Pixbuf.new(RsConfig::ICON_STATE_DISCONNECT, 24, 24))
        iter.set_value(1, %Q[<span weight="bold" size="large">#{login.to_s}</span>])
        if (File.exist?("#{RsConfig::CONTACTS_PHOTO_DIR + File::SEPARATOR + login.to_s}"))
          iter.set_value(2, Gdk::Pixbuf.new("#{RsConfig::CONTACTS_PHOTO_DIR + File::SEPARATOR + login.to_s}", 32, 32))
        else
          iter.set_value(2, Gdk::Pixbuf.new("#{RsConfig::CONTACTS_PHOTO_DIR + File::SEPARATOR}login_l", 32, 32))
        end
        iter.set_value(3, login.to_s)
        iter.set_value(4, "num_session")
        iter.set_value(5, "status")
        iter.set_value(6, "user_data")
        iter.set_value(7, "location")
      elsif val[:connections].length == 1
        val[:connections].each do |ke, va|
          iter = @user_model.prepend(nil)
          iter.set_value(0, Gdk::Pixbuf.new(get_status_icon(va[:status]), 24, 24))
          iter.set_value(1, %Q[<span weight="bold" size="large">#{login.to_s}</span>])
          if (File.exist?("#{RsConfig::CONTACTS_PHOTO_DIR + File::SEPARATOR + login.to_s}"))
            iter.set_value(2, Gdk::Pixbuf.new("#{RsConfig::CONTACTS_PHOTO_DIR + File::SEPARATOR + login.to_s}", 32, 32))
          else
            iter.set_value(2, Gdk::Pixbuf.new("#{RsConfig::CONTACTS_PHOTO_DIR + File::SEPARATOR}login_l", 32, 32))
          end
          iter.set_value(3, login.to_s)
          iter.set_value(4, ke.to_s)
          iter.set_value(5, va[:status])
          iter.set_value(6, va[:user_data])
          iter.set_value(7, va[:location])
        end
      elsif val[:connections].length > 1
        iter = @user_model.prepend(nil)
        iter.set_value(0, Gdk::Pixbuf.new(RsConfig::ICON_MULTICONNECT, 24, 24))
        iter.set_value(1, %Q[<span weight="bold" size="large">#{login.to_s}</span>])
        if (File.exist?("#{RsConfig::CONTACTS_PHOTO_DIR + File::SEPARATOR + login.to_s}"))
          iter.set_value(2, Gdk::Pixbuf.new("#{RsConfig::CONTACTS_PHOTO_DIR + File::SEPARATOR + login.to_s}", 32, 32))
        else
          iter.set_value(2, Gdk::Pixbuf.new("#{RsConfig::CONTACTS_PHOTO_DIR + File::SEPARATOR}login_l", 32, 32))
        end
        iter.set_value(3, login.to_s)
        iter.set_value(4, "num_session")
        iter.set_value(5, "status")
        iter.set_value(6, "user_data")
        iter.set_value(7, "location")
        val[:connections].each do |k, v|
          it = @user_model.append(iter)
          it.set_value(0, Gdk::Pixbuf.new(get_status_icon(v[:status]), 24, 24))
          limit_location = 15
          my_location = v[:location].to_s.slice(0, limit_location.to_i)
          if v[:location].to_s.length > limit_location.to_i
            my_location += "..."
          end
          it.set_value(1, %Q[<span weight="normal" size="x-small"> - #{my_location.to_s} on #{v[:user_data].to_s.slice(0, 23)}</span>])
          it.set_value(2, nil)
          it.set_value(3, login.to_s)
          it.set_value(4, k.to_s)
          it.set_value(5, v[:status].to_s)
          it.set_value(6, v[:user_data].to_s)
          it.set_value(7, v[:location].to_s)
          it.set_value(8, "children")
        end
      end
    end
  end
  def rsng_state_box_init
    model = Gtk::ListStore.new(String, Gdk::Pixbuf, String)
    @rsng_state_box.set_model(model)
    renderer = Gtk::CellRendererPixbuf.new
    @rsng_state_box.pack_start(renderer, false)
    @rsng_state_box.set_attributes(renderer, :pixbuf => 1)
    renderer = Gtk::CellRendererText.new
    @rsng_state_box.pack_end(renderer, true)
    @rsng_state_box.set_attributes(renderer, :text => 2)
    [["actif", Gdk::Pixbuf.new(RsConfig::ICON_STATE_ACTIF, 24, 24), "Actif"],
    ["away", Gdk::Pixbuf.new(RsConfig::ICON_STATE_AWAY, 24, 24), "Away"],
    ["busy", Gdk::Pixbuf.new(RsConfig::ICON_STATE_BUSY, 24, 24), "Busy"],
    ["idle", Gdk::Pixbuf.new(RsConfig::ICON_STATE_IDLE, 24, 24), "Idle"],
    ["lock", Gdk::Pixbuf.new(RsConfig::ICON_STATE_LOCK, 24, 24), "Lock"]].each do |state, icon, name|
      iter = model.append()
      #iter[0] = state
      iter[1] = icon
      iter[2] = name
    end
    @rsng_state_box.set_sensitive(false)
    @rsng_state_box.signal_connect("changed") do
      if (@ns.authenticated)
        send_cmd( NetSoul::Message.set_state(@rsng_state_box.active_iter[2].to_s.downcase(), @ns.get_server_timestamp()) )
        @rs_config.conf[:state] = @rsng_state_box.active_iter[2].to_s.downcase()
        @rs_config.save()
      end
    end
  end
  def rsng_state_box_update
    if (@ns.authenticated)
      @rsng_state_box.set_sensitive(true)
      case @rs_config.conf[:state]
      when "actif"
        @rsng_state_box.active = 0
      when "away"
        @rsng_state_box.active = 1
      when "busy"
        @rsng_state_box.active = 2
      when "idle"
        @rsng_state_box.active = 3
      when "lock"
        @rsng_state_box.active = 4
      else
        @rsng_state_box.active = 0
      end
    else
      @rsng_state_box.set_sensitive(false)
    end
  end
  def get_status_icon(status)
    res = String.new
    case status.to_s
    when "actif"
      res = RsConfig::ICON_STATE_ACTIF
    when "login"
      res = RsConfig::ICON_STATE_LOGIN
    when "connection"
      res = RsConfig::ICON_STATE_CONNECTION
    when "away"
      res = RsConfig::ICON_STATE_AWAY
    when "idle"
      res = RsConfig::ICON_STATE_IDLE
    when "busy"
      res = RsConfig::ICON_STATE_BUSY
    when "lock"
      res = RsConfig::ICON_STATE_LOCK
    when "server"
      res = RsConfig::ICON_STATE_SERVER
    when "logout"
      res = RsConfig::ICON_STATE_LOGOUT
    else
      res = RsConfig::ICON_STATE_DISCONNECT
    end
    return res
  end
  #--- | Contacts window
  def on_contact_delete_event(widget, event)
    @contact_win.hide_all()
  end
  def on_contact_add_entry_activate(widget)
    on_contact_add_btn_clicked(widget)
  end
  def on_contact_add_btn_clicked(widget)
    if @contact_add_entry.text.length > 0
      login = @contact_add_entry.text
      @rs_contact.add(login, true)
      @contact_add_entry.text = ""
      @rs_contact.get_users_photo()
      h = @user_model.append(nil)
      h.set_value(0, Gdk::Pixbuf.new(RsConfig::ICON_DISCONNECT, 24, 24))
      h.set_value(1, %Q[<span weight="bold" size="large">#{login.to_s}</span>])
      if (File.exist?("#{RsConfig::CONTACTS_PHOTO_DIR + File::SEPARATOR + login.to_s}"))
        h.set_value(2, Gdk::Pixbuf.new("#{RsConfig::CONTACTS_PHOTO_DIR + File::SEPARATOR + login.to_s}", 32, 32))
      else
        h.set_value(2, Gdk::Pixbuf.new("#{RsConfig::CONTACTS_PHOTO_DIR + File::SEPARATOR}login_l", 32, 32))
      end
      h.set_value(3, login.to_s)
      h.set_value(4, "num_session")
      h.set_value(5, "state")
      h.set_value(6, "user_data")
      h.set_value(7, "location")
      if @ns.authenticated
        send_cmd( NetSoul::Message.who_users(@rs_contact.get_users_list()) )
        send_cmd( NetSoul::Message.watch_users(@rs_contact.get_users_list()) )
      end
    else
      RsInfobox.new(@contact_win, "No must specify the login", "warning")
    end
  end
  def on_contact_close_btn_clicked(widget)
    @contact_win.hide_all()
  end

  #--- | Preferences window
  def preferences_account_init
    @account_login_entry			= @glade['account_login_entry']
    @account_socks_password_entry		= @glade['account_socks_password_entry']
    @account_unix_password_entry		= @glade['account_unix_password_entry']
    @account_server_host_entry			= @glade['account_server_host_entry']
    @account_server_port_entry			= @glade['account_server_port_entry']
    @account_connection_type_md5		= @glade['account_connection_type_md5']
    @account_connection_type_krb5		= @glade['account_connection_type_krb5']
    @account_location_entry			= @glade['account_location_entry']
    @account_user_group_entry			= @glade['account_user_group_entry']
    @account_connection_at_startup_checkbox	= @glade['account_connection_at_startup_checkbox']
  end
  def preferences_account_load_config(conf)
    if conf[:login].to_s.length > 0
      @account_login_entry.text = conf[:login].to_s
    end
    if conf[:socks_password].to_s.length > 0
      @account_socks_password_entry.text = conf[:socks_password].to_s
    end
    if conf[:unix_password].to_s.length > 0
      @account_unix_password.text = conf[:unix_password].to_s
    end
    if conf[:server_host].to_s.length > 0
      @account_server_host_entry.text = conf[:server_host].to_s
    else
      @account_server_host_entry.text = conf[:server_host] = "ns-server.epita.fr"
    end
    if conf[:server_port].to_s.length > 0
      @account_server_port_entry.text = conf[:server_port].to_s
    else
      @account_server_port_entry.text = conf[:server_port] = "4242"
    end
    conf[:connection_type].eql?("krb5") ? @account_connection_type_krb5.set_active(true) : @account_connection_type_md5.set_active(true)
    if conf[:location].to_s.length > 0
      @account_location_entry.text = conf[:location].to_s
    end
    if conf[:user_group].to_s.length > 0
      @account_user_group_entry.text = conf[:user_group].to_s
    end
    conf[:connection_at_startup].eql?(true) ? @account_connection_at_startup_checkbox.set_active(true) : @account_connection_at_startup_checkbox.set_active(false)
  end
  def preferences_account_save_config
    @rs_config.conf[:login] = @account_login_entry.text if @account_login_entry.text.length > 0
    @rs_config.conf[:socks_password] = @account_socks_password_entry.text if @account_socks_password_entry.text.length > 0
    @rs_config.conf[:unix_password] = @account_unix_password_entry.text if @account_unix_password_entry.text.length > 0
    @rs_config.conf[:server_host] = @account_server_host_entry.text if @account_server_host_entry.text.length > 0
    @rs_config.conf[:server_port] = @account_server_port_entry.text if @account_server_port_entry.text.length > 0
    @rs_config.conf[:connection_type] = @account_connection_type_krb5.active?() ? "krb5" : "md5"
    @rs_config.conf[:location] = @account_location_entry.text if @account_location_entry.text.length > 0
    @rs_config.conf[:user_group] = @account_user_group_entry.text if @account_user_group_entry.text.length > 0
    @rs_config.conf[:connection_at_startup] = @account_connection_at_startup_checkbox.active?() ? true : false
    @rs_config.save()
  end
  def on_preferences_delete_event(widget, event)
    @preferences_win.hide_all()
  end
  def on_preferences_close_btn_clicked(widget)
    @preferences_win.hide_all()
  end
  def on_preferences_validate_btn_clicked(widget)
    preferences_account_save_config()
    @preferences_win.hide_all()
  end

  #--- | About window
end

### MAIN APPLICATION ###
########################
if __FILE__ == $0
  Gtk.init()
  RubySoulNG.new
  Gtk.main()
end

