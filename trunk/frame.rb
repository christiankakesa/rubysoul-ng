=begin
  Frame properties for RSOULng.
=end
begin
  require 'socket_soul'
  require 'contact'
  require 'dialog_chat'
rescue LoadError
end

class Frame < Gtk::Window
  def initialize
    super(Gtk::Window::TOPLEVEL)
    set_icon(Gdk::Pixbuf.new(RS_IMG_LOGO))
  end
end

class UserView < Gtk::ScrolledWindow
  attr_accessor :contacts, :users_dialog

  def initialize(contact_array, socket)
    super()
    set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_AUTOMATIC)
    @contacts = contact_array
    @user_dialogs = Hash.new
    @photo_dir = File.dirname(__FILE__) + File::SEPARATOR + "images" + File::SEPARATOR + "contacts" + File::SEPARATOR
    @user_model = Gtk::TreeStore.new(Gdk::Pixbuf, String, Gdk::Pixbuf, String, String, String)
    @user_model.set_sort_column_id(1)
    @pix_status_renderer = Gtk::CellRendererPixbuf.new
    @pix_status_renderer.set_xalign(0.5)
    @pix_status_renderer.set_yalign(0.0)
    @str_ll_renderer = Gtk::CellRendererText.new
    @str_ll_renderer.set_alignment(Pango::ALIGN_LEFT)
    @str_ll_renderer.set_wrap_mode(Pango::Layout::WRAP_CHAR)
    @pix_photo_renderer = Gtk::CellRendererPixbuf.new
    @pix_photo_renderer.set_xalign(0.0)
    @pix_photo_renderer.set_yalign(0.0)
    @status_column = Gtk::TreeViewColumn.new("Status", @pix_status_renderer, :pixbuf => 0)
    @status_column.set_min_width(24)
    @login_ll_column = Gtk::TreeViewColumn.new("Login / Location", @str_ll_renderer, :markup => 1)
    @login_ll_column.set_min_width(186)
    @photo_column = Gtk::TreeViewColumn.new("Photo", @pix_photo_renderer, :pixbuf => 2)
    @photo_column.set_min_width(32)
    @tv = Gtk::TreeView.new(@user_model)
    @tv.append_column(@status_column)
    @tv.append_column(@login_ll_column)
    @tv.append_column(@photo_column)
    @tv.headers_visible = false
    @tv.reorderable = false
    @tv.signal_connect("row-activated") do |view, path, column|
       get_user_dialog(socket, view.model.get_iter(path)[3], view.model.get_iter(path)[4], @photo_dir + view.model.get_iter(path)[3].to_s, view.model.get_iter(path)[5]).show
    end
    fill_treeview()
    add(@tv)
  end
  
  def get_status_icon(status)
    res = String.new
    case status.to_s
    when "actif"
      res = RS_ICON_STATE_ACTIVE
    when "login"
      res = RS_ICON_STATE_LOCK
    when "away"
      res = RS_ICON_STATE_AWAY
    when "idle"
      res = RS_ICON_STATE_IDLE
    when "lock"
      res = RS_ICON_STATE_LOCK
    when "server"
      res = RS_ICON_STATE_SERVER
    when "logout"
      res = RS_ICON_STATE_DISCONNECT
    else
      res = RS_ICON_STATE_DISCONNECT
    end
    return res
  end

  def login_user_status(login, socket, status)
    @user_model.each do |model,path,iter|
      if (iter[3].to_s == login.to_s)
        it = @user_model.append(iter)
        it.set_value(0, Gdk::Pixbuf.new(fGetStatusIcon(status.to_s), 24, 24))
        it.set_value(1, %Q[<span weight="normal" size="small">#{status.to_s}</span>])
        it.set_value(2, nil)
        it.set_value(3, login.to_s)
        it.set_value(4, socket.to_s)
        it.set_value(5, status.to_s)
      end
    end
    return true
  end

  def get_user_dialog(socket, user_login, user_socket_id, user_pix_path, user_status)
    puts "user_login == #{user_login}"
    puts "user_socket_id == #{user_socket_id}"
    puts "user_pix_path == #{user_pix_path}"
    puts "user_status == #{user_status}"
    if not (@user_dialogs.has_key?(user_socket_id.to_s))
      @user_dialogs[user_socket_id.to_s] = C_DialogChat.new(self, socket, user_login, user_socket_id, user_pix_path, user_status)
    end
    return @user_dialogs[user_socket_id.to_s]
  end
  
  def add_user_status(login, socket, status)
    @user_model.each do |model,path,iter|
      if (iter[3].to_s == login.to_s)
        if (@contacts[login.to_s].include?(:state))
          iter.set_value(0, Gdk::Pixbuf.new(RS_IMG_MULTICONNECT, 24, 24))
          @contacts[login.to_s][:state].each do |sock, value|
            if (socket.to_s == sock.to_s)
              it = @user_model.append(iter)
              it.set_value(0, Gdk::Pixbuf.new(fGetStatusIcon(value[:status].to_s), 24, 24))
              l = value[:status].to_s + "@" + value[:location].to_s
              it.set_value(1, %Q[<span weight="normal" size="small">#{l}</span>])
              it.set_value(2, nil)
              it.set_value(3, login.to_s)
              it.set_value(4, sock.to_s)
              it.set_value(5, value[:status].to_s)
            end
          end
        end
      end
    end
    return true
  end

  def del_user_status(login, socket, status)
    @user_model.each do |model,path,iter|
      if (iter[4].to_s == socket.to_s.to_s)
        model.remove(iter)
      end
    end
    return true
  end

  def update_user_status(login, socket, status)
    @user_model.each do |model,path,iter|
      if (iter[4].to_s == socket.to_s.to_s)
        iter.set_value(0, Gdk::Pixbuf.new(fGetStatusIcon(status.to_s), 24, 24))
        l = status.to_s + "@" + @contacts[login.to_s][:state][socket.to_i][:location].to_s
        iter.set_value(1, %Q[<span weight="normal" size="small">#{l}</span>])
        return true
      end
    end
    add_user_status(login, socket, status)
    return true
  end

  def fill_treeview
    @user_model.clear
    @contacts.each do |k, v|
      add_user(k.to_s)
    end
    return true
  end
  
  def add_user(login)
    h = @user_model.append(nil)
    h.set_value(0, Gdk::Pixbuf.new(RS_IMG_DISCONNECT, 24, 24))
    h.set_value(1, %Q[<span weight="bold" size="large">#{login.to_s}</span>])
    if (File.exist?(@photo_dir + login.to_s))
      h.set_value(2, Gdk::Pixbuf.new(@photo_dir + login.to_s, 32, 32))
    else
      h.set_value(2,  Gdk::Pixbuf.new(@photo_dir + "login_l", 32, 32))
    end
    h.set_value(3, login.to_s)
    h.set_value(4, nil)
    h.set_value(5, nil)
  end
  
  def all_users_off
    @contacts.each do |k, v|
      if (v.include?(:state))
         @contacts[k.to_s].delete(:state)
      end
    end
    fill_treeview()
  end
end

class MainFrame < Frame
  attr_reader :connect, :s, :t, :t_status, :status_bar, :status_box, :user_view, :menu
  attr_accessor :contacts
  
  def initialize
    super()
    ## type = Gtk::Window::TOPLEVEL
    set_title(RS_APP_NAME + " V" + RS_VERSION)
    set_border_width(0)
    set_default_size(RS_DEFAULT_SIZE_W, RS_DEFAULT_SIZE_H)
    @connect = false
    @t = nil
    @s = SocketSoul.new
    ping_res = Ping.pingecho(RS_HOST, 2, RS_PORT)
    if not (ping_res)
      puts '/!\ Netsoul server is not reacheable...'
      @s.log_error("Netsoul server is not reacheable...")
      quit()
    end
    ## Don't move this after before creating @contact instance
    @contact = Contact.new
    @contact.get_users_photo()
    @user_view = UserView.new(@contact.contacts, @s)
    @menu = get_menu()
    @status_box = get_status_box()
    ## ContextId for statusbar :: init, connect, disconnect ##
    ##########################################################
    @status_bar = Gtk::Statusbar.new
    @ctx_init_id = @status_bar.get_context_id("init")
    @ctx_connect_id = @status_bar.get_context_id("connect")
    @ctx_disconnect_id = @status_bar.get_context_id("disconnect")
    @ctx_im_id = @status_bar.get_context_id("im") ## Instant messaging context for information in chat.
    @ctx_current_id = @ctx_init_id
    @status_bar.push(@ctx_init_id, RS_APP_NAME + " by Christian KAKESA")
    ##########################################################
    server_connect()
  end
  
  def get_menu
    accel_group = Gtk::AccelGroup.new
    add_accel_group(accel_group)
    item_factory = Gtk::ItemFactory.new(Gtk::ItemFactory::TYPE_MENU_BAR, '<main>', accel_group)
    menu_items = [
		  #FILE
		  ["/_File"],
		  ["/_File/_Connect", Gtk::ItemFactory::IMAGE_ITEM, "<control>C", Gdk::Pixbuf.new(RS_IMG_CONNECT, 15, 15), Proc.new{server_connect()}],
		  ["/_File/_Disconnect", Gtk::ItemFactory::IMAGE_ITEM,"<control>D", Gdk::Pixbuf.new(RS_IMG_DISCONNECT, 15, 15), Proc.new{server_disconnect()}],
		  ["/_File/sep1", '<Separator>'],
		  ["/_File/Send _Message To..",Gtk::ItemFactory::IMAGE_ITEM,"<control>M", Gdk::Pixbuf.new(RS_IMG_SEND_MSG, 15, 15), Proc.new{send_message_to()}],
		  ["/_File/sep2", '<Separator>'],
		  ["/_File/_Quit", Gtk::ItemFactory::STOCK_ITEM,"<control>Q", Gtk::Stock::QUIT, Proc.new{quit()}],
		  #OPTIONS
		  ["/_Options"],
		  #["/_Options/_Preferences", Gtk::ItemFactory::STOCK_ITEM, "F5", Gtk::Stock::PREFERENCES, Proc.new{fPrefs}],
		  #["/_Options/_Add Contact", Gtk::ItemFactory::IMAGE_ITEM,"<control>L", Gdk::Pixbuf.new(RS_IMG_CONTACT, 15, 15), Proc.new{fAddContact}],
		  #["/_Options/sep3", '<Separator>'],
		  #["/_Options/_Contact Informations",Gtk::ItemFactory::IMAGE_ITEM,"<control>I", Gdk::Pixbuf.new(RS_IMG_CONTACT, 15, 15), Proc.new{fUserInfo}],
		  #Plugins
		  ["/_Tools"],
		  #Help
		  ["/_Help"],
		  ["/_Help/_About", Gtk::ItemFactory::STOCK_ITEM,"<control>A", Gtk::Stock::DIALOG_INFO, Proc.new{get_menu_about()}]
                 ]
    item_factory.create_items(menu_items)
    menu = item_factory.get_widget('<main>')
    return menu
  end
  
  def get_status_box
    model = Gtk::ListStore.new(Gdk::Pixbuf, String, String, String)
    [[Gdk::Pixbuf.new(RS_ICON_STATE_ACTIVE, 24, 24), "Actif", "actif"],
     [Gdk::Pixbuf.new(RS_ICON_STATE_AWAY, 24, 24), "Away", "away"],
     [Gdk::Pixbuf.new(RS_ICON_STATE_IDLE, 24, 24), "Idle", "idle"],
     [Gdk::Pixbuf.new(RS_ICON_STATE_LOCK, 24, 24), "Lock", "lock"]].each do |icon, name, status|
      iter = model.append
      iter[0] = icon
      iter[1] = name
      iter[2] = status
    end
    
    sb = Gtk::ComboBox.new(model)
    renderer = Gtk::CellRendererPixbuf.new
    sb.pack_start(renderer, false)
    sb.set_attributes(renderer, :pixbuf => 0)
    renderer = Gtk::CellRendererText.new
    sb.pack_start(renderer, true)
    sb.set_attributes(renderer, :text => 1)
    sb.sensitive = false
    sb.signal_connect("changed") do
      if (@connect)
        @s.set_user_status(sb.active_iter[2])
      end
    end
    return sb
  end
  
  def update_status_box
    if (@connect)
      @status_box.sensitive = true
      case @s.user[:status]
      when "actif"
        @status_box.active = 0
      when "away"
        @status_box.active = 1
      when "idle"
        @status_box.active = 2
      when "lock"
        @status_box.active = 3
      else
        @status_box.active = 0
      end
    else
      @status_box.sensitive = false
    end
  end
  
  def server_connect
    ping_res = Ping.pingecho(RS_HOST, 2, RS_PORT)
    if not (ping_res)
      puts '/!\ Netsoul server is not reacheable...'
      @s.log_error("Netsoul server is not reacheable...")
      quit()
    end

    if not (@connect)
      rs = @s.auth(@s.user[:login], @s.user[:pass], RS_AGENT, @s.user[:status])
      if (rs)
        @connect = true
        update_status_box()
        #TODO Need here to disable disconnect button if connected.
        mutex = Mutex.new
        if (@t.nil?)
          @t = Thread.new do
            mutex.synchronize {
              while (true) do
              	if (@connect or !@s.sock.nil?)
                  parse_cmd()
                else
                  @connect = false
                  server_connect()
              	end
              end
            }
          end
        end
        if (@s.user_from == "ext")
          @contact.url_photo = "http://intra.epitech.eu/intra/photo.php?login="
        else
          @contact.url_photo = "http://intra/photo.php?login="
        end
        @s.log_info("Authentification success...")
        set_status(@ctx_disconnect_id, "You are connected...")
        @user_view.show_all
        @s.who_users(@contact.get_users_list())
        @s.watch_users(@contact.get_users_list())
      else
        @s.log_erreur("Authentification failed..., Can't auth to NetSoul Server...")
        set_status(@ctx_disconnect_id, "Can't auth to NetSoul Server...")
      end
    end
  end
  
  def server_disconnect
    if (@connect)
      @s.disconnect()
      if not (@t.nil? || !@t.alive? || !@t)
        @t.kill!
        @t = nil
      end
      @user_view.all_users_off()
      @user_view.hide()
      @s.log_info("You are disconnected...")
      @s.log_close()
    end
    @connect = false
    update_status_box()
    set_status(@ctx_disconnect_id, "You are disconnected...")
    ## TODO Need here to disable connect button.
  end
  
  def get_menu_about
    ad = Gtk::AboutDialog.new
    ad.set_modal(true)
    ad.set_title(RS_APP_NAME + " V" + RS_VERSION)
    string = String.new
    license = File.new(File.dirname(__FILE__) + File::SEPARATOR + "LICENSE", "r")
    license.each_line do |line|
      string << line
    end
    license.close()
    ad.license = string; string = nil;
    ad.artists = ["MSN ICONS:\n\t2005 Enhanced Labs | Michael Gonzalez | http://enhancedlabs.com"]
    ad.authors = [RS_AUTHOR_NAME + " " + RS_AUTHOR_FIRSTNAME + "\n<" + RS_AUTHOR_EMAIL + ">"]
    ad.comments = "ETNA/EPITECH/EPITA/IPSA/ISBP auth & instant messaging"
    ad.copyright = "Copyright (C) 2006 " + RS_AUTHOR_NAME + " " + RS_AUTHOR_FIRSTNAME
    ad.name = RS_APP_NAME
    ad.version = RS_VERSION
    ad.website = "Report to: " + RS_AUTHOR_EMAIL
    ad.logo = Gdk::Pixbuf.new(RS_IMG_LOGO)
    ad.set_icon(Gdk::Pixbuf.new(RS_IMG_LOGO))
    ad.signal_connect('response') do
      ad.destroy()
    end	
    ad.show_all()
  end
  
  def send_message_to
    if (@connect)
      dialog = Gtk::Dialog.new( "Send Message To...",
                                self,
                                Gtk::Dialog::DESTROY_WITH_PARENT,
                                [ Gtk::Stock::OK, Gtk::Dialog::RESPONSE_NONE ])
      dialog.set_modal(false)
      login_entry = Gtk::Entry.new
      login_entry.set_max_length(8)
      dialog.vbox.pack_start(Gtk::Frame.new("User login").set_size_request(250, 60).add(login_entry), false, true)
      msg_buffer = Gtk::TextBuffer.new
      msg_box = Gtk::TextView.new(msg_buffer)
      msg_box.set_border_width(0)
      dialog.vbox.pack_start(Gtk::Frame.new("Message").set_size_request(250, 200).add(msg_box), false, true)
      dialog.set_resizable(false)
      dialog.signal_connect('response') do
        if (login_entry.text != "" && msg_buffer.text != "")
          @s.send_msg(login_entry.text, msg_buffer.text)
        end
        msg_buffer.text = ""
      end
      dialog.show_all()
    else
      @s.log_warn("Your are not connected, you can't send a message with \"Send Message To...\" dialogbox. Try to connect before")
    end
  end

  def parse_cmd
    if (@s.sock && @connect)
      buff = @s.sock_get
      case buff.match(/^(\w+)/)[1]
      when "ping"
        ping(buff)
        return true
      when "rep"
        rep(buff)
        return true
      when "user_cmd"
        user_cmd(buff)
        return true
      when "exec"
        server_exec(buff)
        return true
      else
        @s.log_warn("Unknown command " + buff)
        return false
      end
    else
      @s.log_error("You are not connected")
      set_status(@ctx_disconnect_id, "You are not connected")
      return false
    end
  end
  
  def ping(cmd)
    @s.sock_send(cmd.to_s)
    return true
  end
  
  def rep(cmd)
    msg_num, msg = cmd.match(/^\w+\ (\d{3})\ \-\-\ (.*)/)[1..2]
    case msg_num.to_s
    when "001"
      #Command unknown
      #puts msg_num + ": " + msg
      @s.log_error("[Command unknown] " + msg_num.to_s + ": " + msg)
      return false
    when "002"
      #Nothing to do, all is right
      #puts msg_num + ": " + msg
      @s.log_info("[REP_OK] " +  msg_num.to_s + ": " + msg)
      return true
    when "003"
      #bad number of arguments
      #puts msg_num + ": " + msg
      @s.log_error("[Bad number of arguments]" + msg_num.to_s + ": " + msg)
      return false
    when "033"
      #Login or password incorrect
      #puts "Connexion failed, login or password incorrect..."
      @s.log_error("[Login or password incorrect] " +  msg_num.to_s + ": " + msg)
      return false
    else
      #puts "Something is wrong in \"REP\" command response..."
      @s.log_warn("[Response not Yet implemented] " +  msg_num.to_s + ": " + msg)
      return false
    end
  end

  def server_exec(buff)
    cmd, action = buff.match(/^(\w+)\ (\w+)/)[1..2]
    if (action.match(/reboot/))
      disconnect()
      ## TODO: try to reconnect here!!!
    end
    ## Need to be implemented for the other exec message
    return true
  end

  def user_cmd(usercmd)
    cmd = usercmd.match(/^\w+\ \d*:(\w+):.*/)[1]
    case cmd
    when "mail"
      sender, subject = usercmd.match(/^user_cmd\ [^\ ].*\ \|\ ([^\ ].*)\ \-f\ ([^\ ].*)\ ([^\ ].*)/)[2..3]
      @s.log_debug("Vous avez reçu un email !!!\nDe: " + URI.unescape(sender) + "\nSujet: " + URI.unescape(subject)[1..-2])
      return true
    when "host"
      sender = usercmd.match(/^user_cmd\ [^\ ].*\ \|\ ([^\ ].*)\ ([^\ ].*)\ ([^\ ].*)/)[2]
      @s.log_debug("Appel en en cours... !!!\nDe: " + URI.unescape(sender)[1..-1])
      return true
    when "user"
      sender = usercmd.match(/^user_cmd.*:(.*)@.*/)[1]
      user_info, sub_cmd, msg = usercmd.match(/^user_cmd\ ([^\ ].*)\ \|\ (\w+)\ (.*)$/)[1..3]
      get_user_response(sender, sub_cmd, msg, user_info)
      return true
    else
      @s.log_warn("[user_cmd] : " + usercmd + " - This command is not parsed, please contacte the developper")
      return false
    end
  end
  
  def get_user_response(sender, sub_cmd, msg, user_info)
    ## puts "[user_info] : " + user_info.split(/:/).to_s
    socket, login, trust_level, login_host, workstation_type, location, group = user_info.split(/:/)
    location = URI.unescape(location)
    ## puts "[socket_id - location] : " + socket_id.to_s + " - " + location.to_s
    case sub_cmd
    when "dotnetSoul_UserTyping"
      #| dotnetSoul_UserTyping null dst=kakesa_c
      #puts "dotnetSoul_UserTyping"
      @s.log_debug("[dotnetSoul_UserTyping] : " + sender + " - " + sub_cmd + " - " + msg)
      return true
    when "dotnetSoul_UserCancelledTyping"
      #| dotnetSoul_UserCancelledTyping null dst=kakesa_c
      #puts "dotnetSoul_UserCancelledTyping"
      @s.log_debug("[dotnetSoul_UserCancelledTyping] : " + sender + " - " + sub_cmd + " - " + msg)
      return true
    when "msg"
      #| msg ok dst=kakesa_c
      message, receiver = msg.match(/(.*)\ dst=(.*)/)[1..2]
      uv = @user_view.get_user_dialog(@s, sender, socket, @user_view.photo_dir + sender.to_s, @contact.contacts[sender.to_s][:state][socket.to_i][:status]);
      uv.receive_msg(URI.unescape(message))
      uv.show_all()
      @s.log_debug("[msg] : " + sender + " - " + sub_cmd + " - " + URI.unescape(msg))
      return true
    when "who"
      ## For this command fill a @who_cmd data array with parsed data
      ## puts "who msg : " + msg
      if not (msg.match(/cmd end$/))
        socket, login, user_host, login_timestamp, last_status_change_timestamp, trust_level_low, trust_level_high, workstation_type, location, group, status, user_data  = msg.split(/\ /)
        status = status.split(/:/)[0]
        location = URI.unescape(location)
        user_data = URI.unescape(user_data)
        if not (@contact.contacts[login.to_s].include?(:state))
          @contact.contacts[login.to_s][:state] = Hash.new
        end
        if not (@contact.contacts[login.to_s][:state].include?(socket.to_i))
          @contact.contacts[login.to_s][:state][socket.to_i] = Hash.new
        end
        @contact.contacts[login.to_s][:state][socket.to_i][:status] = status.to_s
        @contact.contacts[login.to_s][:state][socket.to_i][:location] = location.to_s
        @user_view.contacts = @contact.contacts
        @user_view.add_user_status(login.to_s, socket.to_s, status.to_s)
        @s.log_debug("[who] : " + sender + " - " + sub_cmd + " - " + msg)
      end
      return true
    when "state"
      ## puts "state msg : " + msg + " -- " + user_info
      status = msg.split(/:/)[0]
      if not (@contact.contacts[sender.to_s].include?(:state))
        @contact.contacts[sender.to_s][:state] = Hash.new
      end
      if not (@contact.contacts[sender.to_s][:state].include?(socket.to_i))
        @contact.contacts[sender.to_s][:state][socket.to_i] = Hash.new
      end
      @contact.contacts[sender.to_s][:state][socket.to_i][:status] = status.to_s
      @contact.contacts[sender.to_s][:state][socket.to_i][:location] = location.to_s
      @user_view.contacts = @contact.contacts
      @user_view.update_user_status(sender.to_s, socket.to_s, status.to_s)
      @s.log_debug("[state] : " + sender + " - " + sub_cmd + " - " + msg)
      return true
    when "login"
      ## puts "login msg : " + msg + " -- " + user_info
      @user_view.login_user_status(sender.to_s, socket.to_s, sub_cmd.to_s)
      @s.log_debug("[login] : " + sender + " - " + sub_cmd + " - " + msg)
      return true
    when "logout"
      ## puts "logout msg : " + msg
      ## TODO build a function to udate user data in contact.rb
      if (@contact.contacts[sender.to_s].include?(:state))
        @contact.contacts[sender.to_s][:state].delete(socket.to_i)
      end
      @user_view.contacts = @contact.contacts
      @user_view.del_user_status(sender.to_s, socket.to_s, sub_cmd.to_s)
      @s.log_debug("[logout] : " + sender + " - " + sub_cmd + " - " + msg)
      return true
    else
      ## puts "sub_cmd not reconize in fGetUserResponse : " + sub_cmd
      @s.log_debug("[unknown sub command] : " + sender + " - " + sub_cmd + " - " + msg)
      return false
    end
  end

  def set_status(ctx_id, msg)
    @status_bar.pop(@ctx_current_id)
    @status_bar.push(ctx_id, msg)
    @ctx_current_id = ctx_id
  end
  
  def get_http_data(url)
    data = String.new
    open(url) do |f|
      data << f.read
    end
    return data
  end

  #--- TODO build Application contact dialogue - tabbed widon with discussion in each tab
  def quit
    server_disconnect()
    Gtk::main_quit()
  end
end
