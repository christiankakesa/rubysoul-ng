#!/usr/bin/ruby -w
=begin
  Made by Christian KAKESA etna_2008(paris) <christian.kakesa@gmail.com>

  TODO: implementer une function at_exit/deconnexion pour quitter proprement netsoul si on ferme l'aaplication'
=end

$KCODE = 'u'

begin
  require 'libglade2'
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
    @aboutdialog = @glade['aboutdialog']
    @user_dialogs = Hash.new

    @rs_config = RsConfig::instance()
    @rs_contact = RsContact::instance()

    rsng_user_view_init()
    rsng_state_box_init()
    preferences_account_init()

    @ns = NetSoul::NetSoul::instance()
    if @rs_config.conf[:connection_at_startup]
      connection()
    end
  end

  def connection
    if @ns.connect()
      @rsng_user_view.set_sensitive(true)
      rsng_state_box_update()
      @parse_thread = Thread.new do
        while (@ns.connected) do
          parse_cmd()
        end
      end
      @ns.sock_send( NetSoul::Message::who_users(@rs_contact.get_users_list()) )
      @ns.sock_send( NetSoul::Message::watch_users(@rs_contact.get_users_list()) )
      @rsng_tb_connect.set_stock_id(Gtk::Stock::DISCONNECT)
      @rsng_tb_connect.set_label("Disconnection")
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
      h.set_value(8, "user_agent")
    end
    @rsng_user_view.set_sensitive(false)
    @rsng_state_box.set_sensitive(false)
    @rs_contact.load_contacts()
  end

  def parse_cmd
    buff = @ns.sock_get()
    case buff.split(' ')[0]
    when "ping"
      ping()
    when "rep"
      rep(buff)
    when "user_cmd"
      user_cmd(buff)
    else
      puts "Unknown command " + buff
    end
  end

  def ping
    @ns.sock_send(NetSoul::Message::ping())
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
    when "003"
      #bad number of arguments
    when "033"
      #Login or password incorrect
      RsInfobox.new(self, "Login or password incorrect", "warning")
    when "140"
      RsInfobox.new(self, "User identification failed", "warning")
    else
      #puts "Something is wrong in \"REP\" command response..."
      puts '[Response not Yet implemented] %s'%[cmd.to_s]
      return false
    end
    return true
  end

  def user_cmd(usercmd)
    cmd, user	= NetSoul::Message::trim(usercmd.split('|')[0]).split(' ')
    response	= NetSoul::Message::trim(usercmd.split('|')[1])
    sub_cmd	= NetSoul::Message::trim(user.split(':')[1])
    case sub_cmd.to_s
    when "mail"
      sender, subject = response.split(' ')[2..3]
      msg = "Vous avez reçu un email !!!\nDe: " + URI.unescape(sender) + "\nSujet: " + URI.unescape(subject)[1..-2]
      RsInfobox.new(self, msg)
      return true
    when "host"
      sender = response.split(' ')[2]
      msg = "Appel en en cours... !!!\nDe: " + URI.unescape(sender)[1..-1]
      RsInfobox.new(self, msg)
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
    when "dotnetSoul_UserTyping"
      #| dotnetSoul_UserTyping null dst=kakesa_c
      puts "[dotnetSoul_UserTyping] : " + sender + " - " + sub_cmd + " - " + response
      return true
    when "typing_start"
      #| dotnetSoul_UserTyping null dst=kakesa_c
      puts "[typing_start] : " + sender + " - " + sub_cmd + " - " + response
      return true
    when "dotnetSoul_UserCancelledTyping"
      #| dotnetSoul_UserCancelledTyping null dst=kakesa_c
      puts "[dotnetSoul_UserCancelledTyping] : " + sender + " - " + sub_cmd + " - " + response
      return true
    when "typing_end"
      #| dotnetSoul_UserCancelledTyping null dst=kakesa_c
      puts "[typing_end] : " + sender + " - " + sub_cmd + " - " + response
      return true
    when "msg"
      msg = URI.unescape(response.split(' ')[1])
      socket = response.split(' ')[1]
      login = sender.to_s
      if not @user_dialogs.include?(login.to_sym)
        @user_dialogs[login.to_sym] = RsDialog.new(login, socket)
        @user_dialogs[login.to_sym].signal_connect("delete-event") do |widget, event|
          @user_dialogs[login.to_sym].hide_all()
        end
      end
      @user_dialogs.receive_msg(login, msg)
      @user_dialogs.has_focus(true)
      @user_dialogs[login.to_sym].show_all()
      puts "[msg] : " + sender + " - " + sub_cmd + " - " + msg
      return true
    when "who"
      if not response.match(/cmd end$/)
        socket = response.split(' ')[1]
        login = response.split(' ')[2]
        status = response.split(' ')[11].split(':')[0]
        user_data = URI.unescape(user.split(':')[6])
        location = URI.unescape(user.split(':')[5])
        user_agent = URI.unescape(response.split(' ')[12])
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
        @rs_contact.contacts[login.to_sym][:connections][socket.to_i][:user_agent] = user_agent.to_s
      else
        rsng_user_view_update()
      end
      puts "[who] : " + sender + " - " + sub_cmd + " - " + response
      return true
    when "state"
      puts "[state] : " + sender + " - " + sub_cmd + " - " + msg
      return true
    when "login"
      puts "[login] : " + sender + " - " + sub_cmd + " - " + msg
      return true
    when "logout"
      puts "[logout] : " + sender + " - " + sub_cmd + " - " + msg
      return true
    else
      puts "[unknown sub command] : " + sender + " - " + sub_cmd + " - " + msg
      return false
    end
  end
  #--- | Main window
  def on_RubySoulNG_delete_event(widget, event)
    disconnection()
    Gtk.main_quit()
  end

  def on_tb_connect_clicked(widget)
    if @ns.connected
      disconnection()
    else
      connection()
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
    @user_model.set_sort_column_id(1)
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
      h.set_value(8, "user_agent")
    end
    @rsng_user_view.signal_connect("row-activated") do |view, path, column|
      if (	view.model.get_iter(path)[5].to_s.eql?("actif") or
      		view.model.get_iter(path)[5].to_s.eql?("away")	or
      		view.model.get_iter(path)[5].to_s.eql?("busy")  or
      		view.model.get_iter(path)[5].to_s.eql?("idle")  or
      		view.model.get_iter(path)[5].to_s.eql?("lock")
      	  )
        login = view.model.get_iter(path)[3]
        num_session = view.model.get_iter(path)[4]
        state = view.model.get_iter(path)[5]
        user_data = view.model.get_iter(path)[6]
        if not @user_dialogs.include?(login.to_sym)
          @user_dialogs[login.to_sym] = RsDialog.new(login, num_session)
          @user_dialogs[login.to_sym].set_can_focus(true)
          @user_dialogs[login.to_sym].signal_connect("delete-event") do |widget, event|
            @user_dialogs[login.to_sym].hide_all()
          end
        end
        @user_dialogs[login.to_sym].show_all()
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
        iter.set_value(8, "user_agent")
      # elsif @rs_contact.contacts[login.to_sym][:connections].length == 1
      elsif val[:connections].length == 1
        val[:connections].each do |ke, va|
		    iter = @user_model.append(nil)
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
		    iter.set_value(8, va[:user_agent])
        end
      elsif val[:connections].length > 1
        iter = @user_model.append(nil)
        iter.set_value(0, Gdk::Pixbuf.new(RsConfig::ICON_MULTICONNECT, 24, 24))
        iter.set_value(1, %Q[<span weight="bold" size="large">#{login.to_s}</span>])
        #if (File.exist?("#{RsConfig::CONTACTS_PHOTO_DIR + File::SEPARATOR + login.to_s}"))
        #  iter.set_value(2, Gdk::Pixbuf.new("#{RsConfig::CONTACTS_PHOTO_DIR + File::SEPARATOR + login.to_s}", 32, 32))
        #else
        #  iter.set_value(2, Gdk::Pixbuf.new("#{RsConfig::CONTACTS_PHOTO_DIR + File::SEPARATOR}login_l", 32, 32))
        #end
        iter.set_value(2, nil)
        iter.set_value(3, login.to_s)
        iter.set_value(4, "num_session")
        iter.set_value(5, "status")
        iter.set_value(6, "user_data")
        iter.set_value(7, "location")
        iter.set_value(8, "user_agent")
		val[:connections].each do |k, v|
		    it = @user_model.append(iter)
		    it.set_value(0, Gdk::Pixbuf.new(get_status_icon(v[:status]), 24, 24))
		    it.set_value(1, %Q[<span weight="bold" size="large">#{v[:user_agent].to_s}</span>])
		    if (File.exist?("#{RsConfig::CONTACTS_PHOTO_DIR + File::SEPARATOR + login.to_s}"))
		      it.set_value(2, Gdk::Pixbuf.new("#{RsConfig::CONTACTS_PHOTO_DIR + File::SEPARATOR + login.to_s}", 32, 32))
		    else
		      it.set_value(2, Gdk::Pixbuf.new("#{RsConfig::CONTACTS_PHOTO_DIR + File::SEPARATOR}login_l", 32, 32))
		    end
		    it.set_value(3, login.to_s)
		    it.set_value(4, k.to_s)
		    it.set_value(5, v[:status])
		    it.set_value(6, v[:user_data])
		    it.set_value(7, v[:location])
		    it.set_value(8, v[:user_agent])
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
      if (@ns.connected)
        @ns.sock_send(NetSoul::Message.set_state(@rsng_state_box.active_iter[2].to_s.downcase(), @ns.get_server_timestamp))
        @rs_config.conf[:state] = @rsng_state_box.active_iter[2].to_s.downcase()
        @rs_config.save()
      end
    end
  end
  def rsng_state_box_update
    if (@ns.connected)
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
      #--- | TODO: If connected send whatch_log and who commands to netsoul server
      if @ns.connected
        @ns.sock_send( NetSoul::Message::who_users(@rs_contact.get_users_list()) )
        @ns.sock_send( NetSoul::Message::watch_users(@rs_contact.get_users_list()) )
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

