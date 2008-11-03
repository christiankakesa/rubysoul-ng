=begin
  Made by Christian KAKESA etna_2008(paris) <christian.kakesa@gmail.com>
=end

begin
  require 'yaml'
  require 'uri'
  require 'open-uri'
  require 'gtk2'
  require 'thread'
  #require 'gtktrayicon'
  require 'lib/netsoul'
  require 'rs_config'
  require 'rs_infobox'
  require 'rs_about'
  require 'rs_contact'
  require 'rs_user_view'
  require 'rs_dialog'
rescue LoadError
  puts "Error: #{$!}"
  exit
end

class MainFrame < Gtk::Window
  attr_reader :ns, :t, :t_status, :status_bar, :status_box, :user_view, :menu

  def initialize
    super(Gtk::Window::TOPLEVEL)
    set_icon(Gdk::Pixbuf.new(RS_IMG_LOGO))
    ## type = Gtk::Window::TOPLEVEL
    set_title(RS_APP_NAME + " V" + RS_VERSION)
    set_border_width(0)
    set_default_size(RS_DEFAULT_SIZE_W, RS_DEFAULT_SIZE_H)
    ## Don't move this after before creating @contact instance
    @parse_mutex = Mutex.new
    @parse_thread = nil
    @ns = NetSoul::NetSoul.new(File.dirname(__FILE__) + File::SEPARATOR + "data" + File::SEPARATOR + "config.yml")
    @contact = RsContact.new
    @contact.get_users_photo()
    @user_view = UserView.new(self, @contact.contacts, @ns)
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
    @status_bar.push(@ctx_init_id, RS_APP_NAME + " " + RS_AUTHOR_FULLNAME)
    ##########################################################
    if (@ns.config[:auto_connect])
      server_connect()
    end
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
      if (@ns.connected)
        @ns.sock_send(NetSoul::Message.set_state(sb.active_iter[2], @ns.get_server_timestamp))
      end
    end
    return sb
  end

  def update_status_box
    if (@ns.connected)
      @status_box.sensitive = true
      case @ns.config[:state]
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
    if not (@ns.connected)
      rs = @ns.connect()
      if (rs)
        update_status_box()
        #TODO Need here to disable disconnect button if connected.
        if (NetSoul::Location::get(@ns.connection_values[:client_ip]) == "ext")
          @contact.url_photo = "http://intra.epitech.eu/intra/photo.php?login="
        else
          @contact.url_photo = "http://intra/photo.php?login="
        end
        set_status(@ctx_disconnect_id, "You are connected...")
        @parse_thread = Thread.new do
          while (@ns.connected) do
            parse_cmd()
          end
        end
        @ns.sock_send( NetSoul::Message::who_users(@contact.get_users_list()) )
        @ns.sock_send( NetSoul::Message::watch_users(@contact.get_users_list()) )
        @user_view.show_all
      else
        set_status(@ctx_disconnect_id, "Can't auth to NetSoul Server...")
      end
    end
  end

  def server_disconnect
    if (@ns.connected)
      @ns.disconnect()
      if (!@parse_thread.nil? && @parse_thread.alive?)
        @parse_thread.kill!
      end
      @parse_thread = nil
      @user_view.all_users_off()
      @user_view.hide()
    end
    update_status_box()
    set_status(@ctx_disconnect_id, "You are disconnected...")
    ## TODO Need here to disable connect button.
  end

  def get_menu_about
    ad = RsAbout.new
    ad.set_modal(true)
    ad.set_title(RS_APP_NAME + " V" + RS_VERSION)
    ad.set_program_name(RS_APP_NAME)
    str = String.new
    l = File.new(File.dirname(__FILE__) + File::SEPARATOR + "data" + File::SEPARATOR + "LICENSE", "rb")
    l.each_line do |line|
      str << line
    end
    l.close
    ad.license = str
    ad.artists = ["MSN ICONS:\n\t2005 Enhanced Labs | Michael Gonzalez | http://enhancedlabs.com"]
    ad.authors = [RS_AUTHOR_FULLNAME + "\n<" + RS_AUTHOR_EMAIL + ">"]
    ad.comments = "ETNA/EPITECH/EPITA/IPSA/ISBP auth & instant messaging"
    ad.copyright = "Copyright (C) 2006 " + RS_AUTHOR_FULLNAME
    ad.name = RS_APP_NAME
    ad.version = RS_VERSION
    ad.website = "Report to: " + RS_AUTHOR_EMAIL
    ad.logo = Gdk::Pixbuf.new(RS_IMG_LOGO)
    ad.set_icon(Gdk::Pixbuf.new(RS_IMG_LOGO))
    ad.signal_connect('response') do
      ad.destroy
    end
    ad.show_all
  end

  def send_message_to
    if (@ns.connected)
      dialog = Gtk::Dialog.new( "Send Message To...",
      self,
      Gtk::Dialog::DESTROY_WITH_PARENT,
      [Gtk::Stock::OK, Gtk::Dialog::RESPONSE_NONE])
      dialog.set_modal(false)
      login_combo = Gtk::Combo.new(@contact.get_users_list().split(',').sort()) #Gtk::Entry.new
      login_combo.entry.set_max_length(8)
      dialog.vbox.pack_start(Gtk::Frame.new("User login").set_size_request(250, 60).add(login_combo), false, true)
      msg_buffer = Gtk::TextBuffer.new
      msg_box = Gtk::TextView.new(msg_buffer)
      msg_box.set_border_width(0)
      dialog.vbox.pack_start(Gtk::Frame.new("Message").set_size_request(250, 200).add(msg_box), false, true)
      dialog.set_resizable(false)
      dialog.signal_connect("response") do
        if (login_combo.entry.text != "" && msg_buffer.text != "")
          @ns.sock_send( NetSoul::Message::send_message(login_combo.entry.text, msg_buffer.text) )
        end
        msg_buffer.text = ""
      end
      dialog.show_all()
    else
      RsInfobox.new(self, "Your are not connected.\nTry to connect before", "warning")
    end
  end

  def parse_cmd
    @parse_mutex.synchronize {
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
    }
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
    case sub_cmd
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
      socket = user.split(":")[0]
=begin
      uv = @user_view.get_user_dialog(@ns, sender, socket, @user_view.photo_dir + sender.to_s, @contact.contacts[sender.to_s][:state][socket.to_i][:status]);
      uv.receive_msg(msg)
      uv.show_all()
=end
      puts "[msg] : " + sender + " - " + sub_cmd + " - " + msg
      return true
    when "who"
      ## For this command fill a @who_cmd data array with parsed data
      if not response.match(/cmd end$/)
        socket = response.split(' ')[1]
        login = response.split(' ')[2]
        status = response.split(' ')[11].split(':')[0]
        location = URI.unescape(user.split(':')[5])
        user_data = URI.unescape(user.split(':')[6])
        if not @contact.contacts[login.to_s].is_a?(Hash)
          @contact.contacts[login.to_s] = Hash.new
        end
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
      end
      puts "[who] : " + sender + " - " + sub_cmd + " - " + response
      return true
    when "state"
      status = response.split(':')[0]
      if not @contact.contacts[sender.to_s].is_a?(Hash)
        @contact.contacts[sender.to_s] = Hash.new
      end
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
      puts "[state] : " + sender + " - " + sub_cmd + " - " + msg
      return true
    when "login"
      @user_view.login_user_status(sender.to_s, socket.to_s, sub_cmd.to_s)
      puts "[login] : " + sender + " - " + sub_cmd + " - " + msg
      return true
    when "logout"
      ## TODO build a function to update user data in contact.rb
      if (@contact.contacts[sender.to_s].include?(:state))
        @contact.contacts[sender.to_s][:state].delete(socket.to_i)
      end
      @user_view.contacts = @contact.contacts
      @user_view.del_user_status(sender.to_s, socket.to_s, sub_cmd.to_s)
      puts "[logout] : " + sender + " - " + sub_cmd + " - " + msg
      return true
    else
      puts "[unknown sub command] : " + sender + " - " + sub_cmd + " - " + msg
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

