#!/usr/bin/ruby
=begin
  Made by Christian KAKESA etna_2008(paris) <christian.kakesa@gmail.com>
	$Author$
	$Revision$ $Date$
=end

$KCODE = 'u'

begin
  require 'libglade2'
  require 'thread'
  require 'ftools'
  require 'fix_gtk'
  require 'lib/netsoul'
  require 'rs_config'
  require 'rs_contact'
  require 'rs_infobox'
  require 'rs_tooltip'
  require 'rs_dialog'
rescue LoadError
  puts "Error: #{$!}"
  exit
end

class RubySoulNG
  include GetText

  attr :glade

  def initialize
    if not GLib::Thread.supported?()
      Glib::Thread.init()
    end
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
    @rsng_win.set_title("#{RsConfig::APP_NAME} #{RsConfig::APP_VERSION}")
    @rsng_win.set_allow_grow(true)
    @rsng_win.set_allow_shrink(true)
    @rsng_win.set_size_request(RsConfig::DEFAULT_SIZE_W, RsConfig::DEFAULT_SIZE_H)
    @rsng_tb_connect = @glade['tb_connect']
    @rsng_user_view = @glade['user_view']
    #@rsng_user_view_tooltip = RsTooltip.new(@rsng_user_view)
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
    @aboutdialog.set_name(RsConfig::APP_NAME)
    @aboutdialog.set_version(RsConfig::APP_VERSION)
    @statusbar = @glade['statusbar']
    @ctx_init_id = @statusbar.get_context_id("init")
    @ctx_offline_id = @statusbar.get_context_id("offline")
    @ctx_online_id = @statusbar.get_context_id("online")
    @ctx_current_id = @ctx_init_id
    @xfer_files_recv = Hash.new
    @xfer_files_send = Hash.new
    @user_online = 0
    @user_dialogs = Hash.new
    @rs_config = RsConfig::instance()
    @rs_contact = RsContact::instance()
    @mutex_send_msg = Mutex.new
    @parse_thread = nil
    Gtk.queue do
      rsng_user_view_init()
    end
    Gtk.queue do
      rsng_state_box_init()
    end
    Gtk.queue do
      print_init_status()
    end
    Gtk.queue do
      preferences_account_init()
    end
    Thread.new do
      preferences_account_load_config(@rs_config.conf)
      Thread.exit()
    end
    start_thread = Thread.new do
      Thread.stop()
      @ns = NetSoul::NetSoul::instance()
      if @rs_config.conf[:connection_at_startup]
        connection()
      end
      Thread.exit()
    end
    Thread.new do
      @rs_contact.contacts.each do |key, value|
        h = @user_model.append(@user_model_iter_offline)
        h.set_value(0, Gdk::Pixbuf.new(RsConfig::ICON_DISCONNECT, 24, 24))
        h.set_value(1, %Q[<span weight="bold">#{key.to_s}</span>])
        if (File.exist?("#{@rs_config.contacts_photo_dir+File::SEPARATOR+key.to_s}"))
          h.set_value(2, Gdk::Pixbuf.new("#{@rs_config.contacts_photo_dir+File::SEPARATOR+key.to_s}", 32, 32))
        else
          h.set_value(2, Gdk::Pixbuf.new(RsConfig::APP_DIR+File::SEPARATOR+'data'+File::SEPARATOR+'img_login_l', 32, 32))
        end
        h.set_value(3, key.to_s)
        h.set_value(4, "num_session")
        h.set_value(5, "status")
        h.set_value(6, "user_data")
        h.set_value(7, "location")
      end
      start_thread.run();
      Thread.exit()
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
      @parse_thread = Thread.new do
        while @ns.sock
          parse_cmd()
          Thread.pass()
        end
        disconnection(false) #without @ns.disconnect()
        Thread.exit()
      end
      Gtk.queue do
        rsng_state_box_update()
      end
      Thread.new do
        send_cmd( NetSoul::Message.who_users(@rs_contact.get_users_list()) )
        Thread.exit()
      end
      Thread.new do
        send_cmd( NetSoul::Message.watch_users(@rs_contact.get_users_list()) )
        Thread.exit()
      end
      Gtk.queue do
        print_online_status()
      end
      return true
    else
      Gtk.queue do
        RsInfobox.new(@rsng_win, "Impossible to connect to the NetSoul server.\n\t- Try to reconnect.", "error", false)
        @preferences_win.show_all()
        @preferences_nbook.set_page(0)
      end
      return false
    end
  end
  def disconnection(ns_server_too = true)
    @ns.disconnect() if ns_server_too
    @xfer_files_recv.clear()
    @xfer_files_send.clear()
    @parse_thread.exit() if @parse_thread.is_a?(Thread)
    #@user_dialogs.each do |d|
    #  d.hide_all() if d.visible?()
    #end
    Gtk.queue do
      @rsng_tb_connect.set_stock_id(Gtk::Stock::CONNECT)
      @rsng_tb_connect.set_label("Connection")
    end
    Thread.new do
      @rs_contact.load_contacts()
    end
    Gtk.queue do
      @user_model.clear()
      @user_model_iter_offline = @user_model.append(nil)
      @user_model_iter_offline.set_value(0, Gdk::Pixbuf.new(RsConfig::ICON_OFFLINE, 24, 24))
      @user_model_iter_offline.set_value(1, %Q[<span weight="bold" size="large">OFFLINE (0/#{@rs_contact.contacts.length})</span>])
      @user_model_iter_offline.set_value(3, "zzzzzz_z")
    end
    if @rs_contact
      Thread.new do
        @rs_contact.contacts.each do |key, value|
          h = @user_model.append(@user_model_iter_offline)
          h.set_value(0, Gdk::Pixbuf.new(RsConfig::ICON_DISCONNECT, 24, 24))
          h.set_value(1, %Q[<span weight="bold">#{key.to_s}</span>])
          if (File.exist?("#{@rs_config.contacts_photo_dir+File::SEPARATOR+key.to_s}"))
            h.set_value(2, Gdk::Pixbuf.new("#{@rs_config.contacts_photo_dir+File::SEPARATOR+key.to_s}", 32, 32))
          else
            h.set_value(2, Gdk::Pixbuf.new(RsConfig::APP_DIR+File::SEPARATOR+'data'+File::SEPARATOR+'img_login_l', 32, 32))
          end
          h.set_value(3, key.to_s)
          h.set_value(4, "num_session")
          h.set_value(5, "status")
          h.set_value(6, "user_data")
          h.set_value(7, "location")
        end
        Thread.exit()
      end
      Gtk.queue do
        @rsng_state_box.set_sensitive(false)
      end
      Gtk.queue do
        print_offline_status()
      end
    end
  end

  def parse_cmd
    begin
      buff = @ns.sock_get().to_s
    rescue
      Thread.new do
        disconnection(false)
        Thread.exit()
      end
      return
    end
    #puts buff
    case buff.split(' ')[0]
    when "ping"
      ping()
    when "rep"
      rep(buff)
    when "user_cmd"
      Thread.new do
        user_cmd(buff)
        Thread.exit()
      end
      return
    else
      if buff.split(' ').length == 12 # list_user, for user location update
        socket = buff.split(' ')[0]
        login = buff.split(' ')[1]
        status = buff.split(' ')[10].split(':')[0]
        user_data = NetSoul::Message.unescape(buff.split(' ')[11])
        location = NetSoul::Message.unescape(buff.split(' ')[8])
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
        if not @user_dialogs.include?(login.to_sym)
          @user_dialogs[login.to_sym] = RsDialog.new(login, socket)
          @user_dialogs[login.to_sym].signal_connect("delete-event") do |widget, event|
            @user_dialogs[login.to_sym].hide_all()
          end
        end
        Thread.new do
          @user_model.each do |model,path,iter|
            if (iter[4].to_s == socket.to_s)
              iter.set_value(0, Gdk::Pixbuf.new(get_status_icon(status.to_s), 24, 24))
              limit_location = 15
              my_location = location.to_s.slice(0, limit_location.to_i)
              if location.to_s.length > limit_location.to_i
                my_location += "..."
              end
              if @rs_contact.contacts[login.to_sym][:connections].length == 1
                iter.set_value(1, %Q[<span weight="bold">#{login.to_s}</span>])
                if (File.exist?("#{@rs_config.contacts_photo_dir+File::SEPARATOR+login.to_s}"))
                  iter.set_value(2, Gdk::Pixbuf.new("#{@rs_config.contacts_photo_dir+File::SEPARATOR+login.to_s}", 32, 32))
                else
                  iter.set_value(2, Gdk::Pixbuf.new(RsConfig::APP_DIR+File::SEPARATOR+'data'+File::SEPARATOR+'img_login_l', 32, 32))
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
          Thread.exit()
        end
      end
    end
  end

  def send_cmd(msg)
    @mutex_send_msg.synchronize do
      begin
        @ns.sock_send(msg)
      rescue
        Thread.new do
          disconnection(false)
          Thread.exit()
        end
      end
    end
  end

  def ping
    Thread.new do
      send_cmd(NetSoul::Message.ping())
      Thread.exit()
    end
    return true
  end

  def rep(cmd)
    msg_num = cmd.split(' ')[1]
    case msg_num.to_s
    when "001"
      #Command unknown
    when "002"
      #Nothing to do, all is right
      #puts '[REP_OK] %s:%s'%[msg_num.to_s, msg]
      return true
    when "003"
      #bad number of arguments
    when "028"
      #watch_log too long
    when "033"
      #Login or password incorrect
      Gtk.queue do
        RsInfobox.new(@rsng_win, "Login or password incorrect", "warning", false)
      end
    when "131"
      #Permision denied
      Gtk.queue do
        RsInfobox.new(@rsng_win, "Permision denied", "warning", false)
      end
    when "140"
      Gtk.queue do
        RsInfobox.new(@rsng_win, "User identification failed", "warning", false)
      end
    else
      puts "Something is wrong in \"REP\" command response..."
      puts '[Response not Yet implemented] cmd:%s - msg_num:%s'%[cmd.to_s, msg_num.to_s]
    end
    return false
  end

  def user_cmd(usercmd)
    cmd, user	= NetSoul::Message.trim(usercmd.split('|')[0]).split(' ')
    response	= NetSoul::Message.trim(usercmd.split('|')[1])
    sub_cmd	= NetSoul::Message.trim(user.split(':')[1])
    case sub_cmd.to_s
    when "mail"
      sender, subject = response.split(' ')[2..3]
      msg = "Vous avez reçu un email !!!\nDe: " + NetSoul::Message.unescape(sender) + "\nSujet: " + NetSoul::Message.unescape(subject)[1..-2]
      Gtk.queue do
        RsInfobox.new(@rsng_win, msg, "info", false)
      end
    when "host"
      sender = response.split(' ')[2]
      msg = "Appel en en cours... !!!\nDe: " + NetSoul::Message.unescape(sender)[1..-1]
      Gtk.queue do
        RsInfobox.new(@rsng_win, msg, "info", false)
      end
    when "user"
      get_user_response(cmd, user, response)
    else
      puts "[user_cmd] : " + usercmd + " - This command is not parsed, please contacte the developper"
    end
  end

  def get_user_response(cmd, user, response)
    sender = user.split(":")[3].split('@')[0]
    sub_cmd = response.split(' ')[0]
    case sub_cmd
    when "desoul_ns_xfer", "desoul_ns_xfer_accept", "desoul_ns_xfer_data", "desoul_ns_xfer_cancel"
      xfer_process_recv(sub_cmd.to_s, user.to_s, response.to_s.split(' ')[1])
    when "dotnetSoul_UserTyping", "typing_start"
      #| dotnetSoul_UserTyping null dst=kakesa_c
      socket = response.split(' ')[1]
      login = sender.to_s
      if @user_dialogs.include?(login.to_sym)
        @user_dialogs[login.to_sym].print_user_typing_status()
      end
    when "dotnetSoul_UserCancelledTyping", "typing_end"
      #| dotnetSoul_UserCancelledTyping null dst=kakesa_c
      socket = response.split(' ')[1]
      login = sender.to_s
      if @user_dialogs.include?(login.to_sym)
        @user_dialogs[login.to_sym].print_init_status()
      end
    when "msg"
      msg = NetSoul::Message.unescape(response.split(' ')[1])
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
      @user_dialogs[login.to_sym].set_urgency_hint(true)
    when "who"
      if not response.match(/cmd end$/)
        socket = response.split(' ')[1]
        login = response.split(' ')[2]
        status = response.split(' ')[11].split(':')[0]
        user_data = NetSoul::Message.unescape(response.split(' ')[12])
        location = NetSoul::Message.unescape(response.split(' ')[9])
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
    when "state"
      login = sender.to_s
      socket = user.split(':')[0].to_s
      status = response.split(' ')[1].split(':')[0].to_s
      @user_model.each do |model,path,iter|
        if (iter[4].to_s == socket.to_s)
          iter.set_value(0, Gdk::Pixbuf.new(get_status_icon(status), 24, 24))
          iter.set_value(5, status)
          @rs_contact.contacts[login.to_sym][:connections][socket.to_i][:status] = status
        end
      end
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
          iter.set_value(1, %Q[<span weight="bold">#{login.to_s}</span>])
          if (File.exist?("#{@rs_config.contacts_photo_dir+File::SEPARATOR+login.to_s}"))
            iter.set_value(2, Gdk::Pixbuf.new("#{@rs_config.contacts_photo_dir+File::SEPARATOR+login.to_s}", 32, 32))
          else
            iter.set_value(2, Gdk::Pixbuf.new(RsConfig::APP_DIR+File::SEPARATOR+'data'+File::SEPARATOR+'img_login_l', 32, 32))
          end
          iter.set_value(3, login.to_s)
          iter.set_value(4, key.to_s)
          iter.set_value(5, val[:status].to_s)
          iter.set_value(6, "user_data")
          iter.set_value(7, "location")
        end
      elsif @rs_contact.contacts[login.to_sym][:connections].length == 2
        @user_model.each do |model,path,iter|
          if (iter[3].to_s == login.to_s)
            iter.set_value(0, Gdk::Pixbuf.new(RsConfig::ICON_MULTICONNECT, 24, 24))
            iter.set_value(1, %Q[<span weight="bold">#{login.to_s}</span>])
            if (File.exist?("#{@rs_config.contacts_photo_dir+File::SEPARATOR+login.to_s}"))
              iter.set_value(2, Gdk::Pixbuf.new("#{@rs_config.contacts_photo_dir+File::SEPARATOR+login.to_s}", 32, 32))
            else
              iter.set_value(2, Gdk::Pixbuf.new(RsConfig::APP_DIR+File::SEPARATOR+'data'+File::SEPARATOR+'img_login_l', 32, 32))
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
      Thread.new do
        send_cmd( NetSoul::Message.list_users(login.to_s) )
        Thread.exit()
      end
      Gtk.queue do
        print_online_status()
      end
    when "logout"
      login = sender.to_s
      socket = user.split(':')[0]
      if @rs_contact.contacts.include?(login.to_sym) && @rs_contact.contacts[login.to_sym].include?(:connections) && @rs_contact.contacts[login.to_sym][:connections].include?(socket.to_i)
        @rs_contact.contacts[login.to_sym][:connections].delete(socket.to_i)
        if @rs_contact.contacts[login.to_sym][:connections].length == 0 # delete and put at bottom
          @user_model.each do |model,path,iter|
            @user_model.remove(iter) if (iter[4].to_s == socket.to_s)
          end
          iter = @user_model.append(@user_model_iter_offline)
          iter.set_value(0, Gdk::Pixbuf.new(RsConfig::ICON_DISCONNECT, 24, 24))
          iter.set_value(1, %Q[<span weight="bold">#{login.to_s}</span>])
          if (File.exist?("#{@rs_config.contacts_photo_dir+File::SEPARATOR+login.to_s}"))
            iter.set_value(2, Gdk::Pixbuf.new("#{@rs_config.contacts_photo_dir+File::SEPARATOR+login.to_s}", 32, 32))
          else
            iter.set_value(2, Gdk::Pixbuf.new(RsConfig::APP_DIR+File::SEPARATOR+'data'+File::SEPARATOR+'img_login_l', 32, 32))
          end
          iter.set_value(3, login.to_s)
          iter.set_value(4, "num_session")
          iter.set_value(5, "status")
          iter.set_value(6, "user_data")
          iter.set_value(7, "location")
          print_online_status()
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
            iter.set_value(1, %Q[<span weight="bold">#{login.to_s}</span>])
            if (File.exist?("#{@rs_config.contacts_photo_dir+File::SEPARATOR+login.to_s}"))
              iter.set_value(2, Gdk::Pixbuf.new("#{@rs_config.contacts_photo_dir+File::SEPARATOR+login.to_s}", 32, 32))
            else
              iter.set_value(2, Gdk::Pixbuf.new(RsConfig::APP_DIR+File::SEPARATOR+'data'+File::SEPARATOR+'img_login_l', 32, 32))
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
      else
        return false
      end
      return true
    end
  end

  def xfer_process_recv(cmd, user, response)
    socket = user.to_s.split(':')[0]
    socket = ":#{socket.to_s}"
    login = user.split(":")[3].split('@')[0]
    response = URI.unescape(response)
    case cmd.to_s
    when "desoul_ns_xfer"
      xfer_recv(socket, login, response)
    when "desoul_ns_xfer_accept"
      xfer_accept_recv(socket, response)
    when "desoul_ns_xfer_data"
      if @xfer_files_recv.include?(response.split(' ')[0].to_s)
        Thread.new do
          @xfer_files_recv[response.split(' ')[0].to_s][:mutex].synchronize {
            xfer_data_recv(socket, response)
          }
          Thread.exit()
        end
      end
    when "desoul_ns_xfer_cancel"
      xfer_cancel_recv(socket, response)
    end
  end

  def xfer_recv(socket, login, response)
    id, filename, size, desc = response.to_s.split(' ')[0..3]
    filename = NetSoul::Message.unescape(filename.to_s)
    desc = NetSoul::Message.unescape(desc.to_s)
    homedir = ENV['HOME'] || ENV['HOMEDRIVE'] + ENV['HOMEPATH'] || ENV['USERPROFILE']
    filepath = homedir + File::SEPARATOR + filename.to_s
    Gtk.queue do
      dialog = Gtk::Dialog.new("#{RsConfig::APP_NAME} #{RsConfig::APP_VERSION}", @rsng_win,
      Gtk::Dialog::DESTROY_WITH_PARENT,
      [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_REJECT],
      [Gtk::Stock::OK, Gtk::Dialog::RESPONSE_ACCEPT])
      dialog.vbox.add(Gtk::Label.new("#{login.to_s} try to send you this file : "))
      dialog.vbox.add(Gtk::Label.new(">> #{filename}"))
      dialog.vbox.add(Gtk::Label.new(">> #{size} bytes"))
      dialog.vbox.add(Gtk::Label.new(">> #{desc}"))
      dialog.show_all()
      dialog.run do |resp|
        case resp
        when Gtk::Dialog::RESPONSE_ACCEPT
          begin
            if not (FileTest.exist?(filepath))
              @xfer_files_recv[id.to_s] = Hash.new
              @xfer_files_recv[id.to_s][:filepath] = filepath
              @xfer_files_recv[id.to_s][:filename] = filename.to_s
              @xfer_files_recv[id.to_s][:total_size] = size.to_i
              @xfer_files_recv[id.to_s][:size] = 0
              @xfer_files_recv[id.to_s][:buffer] = nil
              @xfer_files_recv[id.to_s][:total_buffer_size] = 0
              @xfer_files_recv[id.to_s][:desc] = desc.to_s
              @xfer_files_recv[id.to_s][:mutex] = Mutex.new
              @xfer_files_recv[id.to_s][:fd] = File.new(filepath, "wb")
              Thread.new do
                send_cmd( NetSoul::Message.xfer_accept(socket.to_s, id.to_s) )
                Thread.exit()
              end
            else
              @xfer_files_recv.delete(id.to_s)
              Gtk.queue do
                RsInfobox.new(@rsng_win, "File: #{filepath} already exist", "warning", false)
              end
            end
          rescue
            Gtk.queue do
              RsInfobox.new(@rsng_win, "#{$!}", "error", false)
            end
          end
        end
        dialog.destroy
      end
    end
  end

  def xfer_accept_recv(socket, response)
    Gtk.queue do
      RsInfobox.new(@rsng_win, "Receive xfer request from #{user.to_s}\n#{response.to_s}", "info", false)
    end
  end

  def xfer_data_recv(socket, response)
    begin
      id = response.to_s.split(' ')[0]
      @xfer_files_recv[id.to_s][:buffer] = response.to_s.split(' ')[1].to_s.chomp.unpack("m").to_s
      if (	@xfer_files_recv[id.to_s][:buffer].length >= RsConfig::FILE_BUFFER_SIZE ||
      		@xfer_files_recv[id.to_s][:total_size] <= RsConfig::FILE_BUFFER_SIZE	)
        @xfer_files_recv[id.to_s][:fd].write_nonblock(@xfer_files_recv[id.to_s][:buffer])
        @xfer_files_recv[id.to_s][:size] += @xfer_files_recv[id.to_s][:buffer].length
        @xfer_files_recv[id.to_s][:buffer] = nil
      end
      percent = @xfer_files_recv[id.to_s][:size].to_i * 100 / @xfer_files_recv[id.to_s][:total_size].to_i
      $stdout << "\rcurrent size : #{@xfer_files_recv[id.to_s][:size]} - total size #{@xfer_files_recv[id.to_s][:total_size]} - #{percent}%"
      $stdout.flush
      if @xfer_files_recv[id.to_s][:size] >= @xfer_files_recv[id.to_s][:total_size]
        @xfer_files_recv[id.to_s][:fd].close()
        @xfer_files_recv.delete(id.to_s)
        print "\nOK !!!\n"
      end
    rescue
      puts "Error: #{$!}"
      @xfer_files_recv[id.to_s][:fd].close()
      @xfer_files_recv.delete(id.to_s)
    end
  end

  def xfer_cancel_recv(socket, response)
    id = response.to_s
    if @xfer_files_recv.include?(id.to_s)
      begin
        @xfer_files_recv[id.to_s][:fd].close() if @xfer_files_recv[id.to_s][:fd]
        File.delete(@xfer_files_recv[id.to_s][:filepath]) if FileTest.exist?(@xfer_files_recv[id.to_s][:filepath])
        @xfer_files_recv.delete(id.to_s)
      rescue
        Gtk.queue do
          RsInfobox.new(@rsng_win, "#{$!}", "error", false)
        end
      end
    end
  end

  #--- | Main window
  def on_RubySoulNG_delete_event(widget, event)
    begin
      Thread.new do
        disconnection()
      end
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
      Gtk.queue do
        RsInfobox.new(@rsng_win, "#{$!}", "error", false)
      end
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
    #--- | ICON_STATE, HTML Login, PHOTO, Login, {sublist} SessionNum, State, UserData, Location, Children?
    @user_model = Gtk::TreeStore.new(Gdk::Pixbuf, String, Gdk::Pixbuf, String, String, String, String, String, String)
    @user_model.set_sort_column_id(3)
    @rsng_user_view.set_model(@user_model)
    renderer = Gtk::CellRendererPixbuf.new
    column = Gtk::TreeViewColumn.new("Status", renderer, :pixbuf => 0)
    @rsng_user_view.append_column(column)
    renderer = Gtk::CellRendererText.new
    renderer.set_alignment(Pango::ALIGN_LEFT)
    column = Gtk::TreeViewColumn.new("Login / Location", renderer, :markup => 1)
    column.set_sizing(Gtk::TreeViewColumn::AUTOSIZE)
    @rsng_user_view.append_column(column)
    renderer = Gtk::CellRendererPixbuf.new
    column = Gtk::TreeViewColumn.new("Photo", renderer, :pixbuf => 2)
    column.set_sizing(Gtk::TreeViewColumn::FIXED)
    @rsng_user_view.append_column(column)
    @user_model_iter_offline = @user_model.prepend(nil)
    @user_model_iter_offline.set_value(0, Gdk::Pixbuf.new(RsConfig::ICON_OFFLINE, 24, 24))
    @user_model_iter_offline.set_value(1, %Q[<span weight="bold" size="large">OFFLINE (#{@rs_contact.contacts.length}/#{@rs_contact.contacts.length})</span>])
    @user_model_iter_offline.set_value(3, "zzzzzz_z")
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
        if (iter[8].to_s != "children" || iter[4].to_s == "num_session")
          login = iter[3]
          @user_model.remove(iter)
          @rs_contact.remove(login.to_s, true)
          if @user_dialogs.include?(login.to_sym)
            @user_dialogs[login.to_sym].destroy()
            @user_dialogs.delete(login.to_sym)
          end
          Thread.new do
            send_cmd( NetSoul::Message.watch_users(@rs_contact.get_users_list()) )
            Thread.exit()
          end
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
          if ( iter && iter[8].to_s != "children" && iter[3].to_s != "zzzzzz_z" && iter == @rsng_user_view.selection.selected)
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
    @user_model_iter_offline = @user_model.prepend(nil)
    @user_model_iter_offline.set_value(0, Gdk::Pixbuf.new(RsConfig::ICON_OFFLINE, 24, 24))
    @user_model_iter_offline.set_value(1, %Q[<span weight="bold" size="large">OFFLINE (0/#{@rs_contact.contacts.length})</span>])
    @user_model_iter_offline.set_value(3, "zzzzzz_z")
    @rs_contact.contacts.each do |key, val|
      login = key
      if not @rs_contact.contacts[login.to_sym].include?(:connections)
        iter = @user_model.append(@user_model_iter_offline)
        iter.set_value(0, Gdk::Pixbuf.new(RsConfig::ICON_STATE_DISCONNECT, 24, 24))
        iter.set_value(1, %Q[<span weight="bold">#{login.to_s}</span>])
        if (File.exist?("#{@rs_config.contacts_photo_dir+File::SEPARATOR+login.to_s}"))
          iter.set_value(2, Gdk::Pixbuf.new("#{@rs_config.contacts_photo_dir+File::SEPARATOR+login.to_s}", 32, 32))
        else
          iter.set_value(2, Gdk::Pixbuf.new(RsConfig::APP_DIR+File::SEPARATOR+'data'+File::SEPARATOR+'img_login_l', 32, 32))
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
          iter.set_value(1, %Q[<span weight="bold">#{login.to_s}</span>])
          if (File.exist?("#{@rs_config.contacts_photo_dir+File::SEPARATOR+login.to_s}"))
            iter.set_value(2, Gdk::Pixbuf.new("#{@rs_config.contacts_photo_dir+File::SEPARATOR+login.to_s}", 32, 32))
          else
            iter.set_value(2, Gdk::Pixbuf.new(RsConfig::APP_DIR+File::SEPARATOR+'data'+File::SEPARATOR+'img_login_l', 32, 32))
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
        iter.set_value(1, %Q[<span weight="bold">#{login.to_s}</span>])
        if (File.exist?("#{@rs_config.contacts_photo_dir+File::SEPARATOR+login.to_s}"))
          iter.set_value(2, Gdk::Pixbuf.new("#{@rs_config.contacts_photo_dir+File::SEPARATOR+login.to_s}", 32, 32))
        else
          iter.set_value(2, Gdk::Pixbuf.new(RsConfig::APP_DIR+File::SEPARATOR+'data'+File::SEPARATOR+'img_login_l', 32, 32))
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
    print_online_status()
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
        Thread.new do
          send_cmd( NetSoul::Message.set_state(@rsng_state_box.active_iter[2].to_s.downcase(), @ns.get_server_timestamp()) )
          Thread.exit()
        end
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
      h = @user_model.append(@user_model_iter_offline)
      h.set_value(0, Gdk::Pixbuf.new(RsConfig::ICON_DISCONNECT, 24, 24))
      h.set_value(1, %Q[<span weight="bold">#{login.to_s}</span>])
      if (File.exist?("#{@rs_config.contacts_photo_dir+File::SEPARATOR+login.to_s}"))
        h.set_value(2, Gdk::Pixbuf.new("#{@rs_config.contacts_photo_dir+File::SEPARATOR+login.to_s}", 32, 32))
      else
        h.set_value(2, Gdk::Pixbuf.new(RsConfig::APP_DIR+File::SEPARATOR+'data'+File::SEPARATOR+'img_login_l', 32, 32))
      end
      h.set_value(3, login.to_s)
      h.set_value(4, "num_session")
      h.set_value(5, "state")
      h.set_value(6, "user_data")
      h.set_value(7, "location")
      print_online_status()
      if @ns.authenticated
        Thread.new do
          send_cmd( NetSoul::Message.who_users(@rs_contact.get_users_list()) )
          Thread.exit()
        end
        Thread.new do
          send_cmd( NetSoul::Message.watch_users(@rs_contact.get_users_list()) )
          Thread.exit()
        end
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
    @account_login_entry						= @glade['account_login_entry']
    @account_socks_password_entry		= @glade['account_socks_password_entry']
    @account_unix_password_entry		= @glade['account_unix_password_entry']
    @account_server_host_entry			= @glade['account_server_host_entry']
    @account_server_port_entry			= @glade['account_server_port_entry']
    @account_connection_type_md5		= @glade['account_connection_type_md5']
    @account_connection_type_krb5		= @glade['account_connection_type_krb5']
    @account_location_entry					= @glade['account_location_entry']
    @account_user_group_entry				= @glade['account_user_group_entry']
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
      @account_unix_password_entry.text = conf[:unix_password].to_s
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
    @rs_config.conf[:login] = @account_login_entry.text.to_s if @account_login_entry.text.length > 0
    @rs_config.conf[:socks_password] = @account_socks_password_entry.text.to_s if @account_socks_password_entry.text.length > 0
    @rs_config.conf[:unix_password] = @account_unix_password_entry.text.to_s if @account_unix_password_entry.text.length > 0
    @rs_config.conf[:server_host] = @account_server_host_entry.text.to_s if @account_server_host_entry.text.length > 0
    @rs_config.conf[:server_port] = @account_server_port_entry.text.to_s if @account_server_port_entry.text.length > 0
    ns_token_found = false
    ns_token_found = true if FileTest.exist?(RsConfig::APP_DIR+File::SEPARATOR+"lib/kerberos/NsToken.so")
    ns_token_found = true if FileTest.exist?(RsConfig::APP_DIR+File::SEPARATOR+"lib/kerberos/NsToken.dylib")
    ns_token_found = true if FileTest.exist?(RsConfig::APP_DIR+File::SEPARATOR+"lib/kerberos/NsToken.dll")
    @rs_config.conf[:connection_type] = @account_connection_type_krb5.active?() && ns_token_found ? "krb5" : "md5"
    if @account_connection_type_krb5.active?() && !ns_token_found
      RsInfobox.new(@rsng_win, "NsToken is not build for kerberos authentication, MD5 authentication selected", "warning")
    end
    @rs_config.conf[:location] = @account_location_entry.text.to_s if @account_location_entry.text.length > 0
    @rs_config.conf[:user_group] = @account_user_group_entry.text.to_s if @account_user_group_entry.text.length > 0
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

  #--- | Other stuff
  def print_init_status
    set_status(@ctx_init_id, "#{RsConfig::APP_NAME} #{RsConfig::APP_VERSION}")
  end
  def print_offline_status
    set_status(@ctx_offline_id, "You are not connected !!!")
  end
  def print_online_status
    @user_online = @rs_contact.contacts.length - @user_model_iter_offline.n_children
    @user_model_iter_offline.set_value(1, %Q[<span weight="bold" size="large">OFFLINE (#{@user_model_iter_offline.n_children.to_s}/#{@rs_contact.contacts.length})</span>])
    set_status(@ctx_online_id, "Your are online | Online contacts : #{@user_online.to_s}/#{@rs_contact.contacts.length}")
  end
  def set_status(ctx_id, msg)
    @statusbar.pop(@ctx_current_id) if @ctx_current_id
    @statusbar.push(ctx_id, msg.to_s)
    @ctx_current_id = ctx_id
  end
end

### MAIN APPLICATION ###
########################
if __FILE__ == $0
  Gtk.init()
  RubySoulNG.new
  Gtk.main_with_queue 100
end

