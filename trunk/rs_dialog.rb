=begin
  Made by Christian KAKESA etna_2008(paris) <christian.kakesa@gmail.com>
=end

begin
  require 'gtk2'
  require 'lib/netsoul'
  require 'rs_config'
  require 'rs_infobox'
rescue LoadError
  puts "Error: #{$!}"
  exit
end

class RsDialog < Gtk::Window
  #attr_accessor :receive_msg

  def initialize(login, num_session)
    super("#{login.to_s}")
    @login = login.to_s
    @num_session = num_session.to_i
    @send_typing = false
    @ns = NetSoul::NetSoul::instance()
    @rs_config = RsConfig::instance()
    set_icon(Gdk::Pixbuf.new("#{@rs_config.contacts_photo_dir+File::SEPARATOR+@login}"))
    vbox = Gtk::VBox.new
    hbox = Gtk::HBox.new
    set_modal(false)
    set_destroy_with_parent(true)
    @send_foreground_time = Gtk::TextTag.new("send_foreground_time")
    @send_foreground_time.set_foreground_gdk(Gdk::Color.new(0, 0, 65535))
    @send_foreground_login = Gtk::TextTag.new("send_foreground_login")
    @send_foreground_login.set_foreground_gdk(Gdk::Color.new(0, 0, 65535))
    @send_foreground_login.set_weight(Pango::FontDescription::WEIGHT_BOLD)
    @recv_foreground_time = Gtk::TextTag.new("recv_foreground_time")
    @recv_foreground_time.set_foreground_gdk(Gdk::Color.new(65535, 0, 0))
    @recv_foreground_login = Gtk::TextTag.new("recv_foreground_login")
    @recv_foreground_login.set_foreground_gdk(Gdk::Color.new(65535, 0, 0))
    @recv_foreground_login.set_weight(Pango::FontDescription::WEIGHT_BOLD)
    @dialog_buffer = Gtk::TextBuffer.new
    @dialog_buffer.tag_table.add(@send_foreground_time)
    @dialog_buffer.tag_table.add(@send_foreground_login)
    @dialog_buffer.tag_table.add(@recv_foreground_time)
    @dialog_buffer.tag_table.add(@recv_foreground_login)
    @dialog_view_tv = Gtk::TextView.new(@dialog_buffer)
    @dialog_view_tv.set_editable(false)
    @dialog_view_tv.set_can_focus(false)
    @dialog_view_tv.set_wrap_mode(Gtk::TextTag::WRAP_WORD_CHAR)
    @dialog_view = Gtk::ScrolledWindow.new().add(@dialog_view_tv)
    @dialog_view.set_policy(Gtk::POLICY_NEVER, Gtk::POLICY_AUTOMATIC)
    @dialog_view.set_size_request(400, 200)
    @dialog_view.vadjustment.set_step_increment(10.0)
    @dialog_view.vadjustment.set_page_increment(100.0)
    @send_buffer = Gtk::TextBuffer.new
    @send_view_tv = Gtk::TextView.new(@send_buffer)
    @send_view_tv.set_wrap_mode(Gtk::TextTag::WRAP_WORD_CHAR)
    @send_view_tv.set_can_focus(true)
    @send_view_tv.set_can_default(true)
    @send_view = Gtk::ScrolledWindow.new().add(@send_view_tv)
    @send_view.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_AUTOMATIC)
    @user_img = Gtk::Image.new(Gdk::Pixbuf.new("#{@rs_config.contacts_photo_dir+File::SEPARATOR+@login}", 128, 128))
    @user_img.set_can_focus(false)
    @statusbar = Gtk::Statusbar.new
    @ctx_init_id = @statusbar.get_context_id("init")
    @ctx_user_typing_id = @statusbar.get_context_id("user_typing")
    @ctx_current_id = @ctx_init_id
    print_init_status()
    vbox.pack_start(@dialog_view, true, true, 3)
    hbox.pack_start(@send_view, true, true, 3)
    hbox.pack_end(@user_img, false, false, 3)
    vbox.pack_start(hbox, false, false, 3)
    vbox.pack_end(@statusbar, false, false)
    add(vbox)
    set_focus_child(@send_view_tv)
    @send_view_tv.set_cursor_visible(true) if not @send_view_tv.cursor_visible?
    signal_connect('delete-event') do |widget, ev|
      widget.hide_all()
    end
    signal_connect("key-press-event") do |widget, event|
      @send_view_tv.set_cursor_visible(true) if not @send_view_tv.cursor_visible?
      if event.state & Gdk::Window::ModifierType::CONTROL_MASK != 0 and event.keyval == Gdk::Keyval::GDK_l
        @dialog_buffer.delete(@dialog_buffer.start_iter, @dialog_buffer.end_iter)
        set_focus_child(@send_view_tv)
      else
        case event.keyval
        when Gdk::Keyval::GDK_Return, Gdk::Keyval::GDK_KP_Enter, Gdk::Keyval::GDK_3270_Enter, Gdk::Keyval::GDK_ISO_Enter
          if @send_buffer.text.length > 0
            send_msg(@login, @send_buffer.text)
          end
          set_focus_child(@send_view_tv)
        end
      end
    end
    signal_connect("key-release-event") do |widget, event|
      #--- | Print info in statusbar
      if @send_buffer.text.length > 1 && !@send_typing
        send_start_typing()
      elsif @send_buffer.text.length == 0 && @send_typing
        send_stop_typing()
      end
    end
    signal_connect("focus-in-event") do |widget, event|
      set_urgency_hint(false)
      @send_view_tv.set_cursor_visible(true) if not @send_view_tv.cursor_visible?
    end
  end

  def send_msg(user, msg)
    begin
      if NetSoul::Message::trim(msg.to_s).length > 0
      	msg = NetSoul::Message.trim(msg.to_s)
        @ns.sock_send(NetSoul::Message::send_message(user.to_s, msg.to_s))
        @dialog_buffer.insert(@dialog_buffer.end_iter, "(#{Time.now.strftime("%H:%M:%S")})" , @send_foreground_time)
        @dialog_buffer.insert(@dialog_buffer.end_iter, " #{@rs_config.conf[:login].to_s}:", @send_foreground_login)
        @dialog_buffer.insert(@dialog_buffer.end_iter, " #{msg.to_s}\n")
        @dialog_view.vadjustment.value = @dialog_view.vadjustment.upper - @dialog_view.vadjustment.step_increment
      end
      @send_buffer.delete(@send_buffer.start_iter, @send_buffer.end_iter)
    rescue
      RsInfobox.new(self, "#{$!}", "error")
    end
  end

  def receive_msg(user_from, msg)
    begin
    	msg = NetSoul::Message.trim(msg)
      @dialog_buffer.insert(@dialog_buffer.end_iter, "(#{Time.now.strftime("%H:%M:%S")})", @recv_foreground_time)
      @dialog_buffer.insert(@dialog_buffer.end_iter, " #{user_from.to_s}:", @recv_foreground_login)
      @dialog_buffer.insert(@dialog_buffer.end_iter, " #{msg.to_s}\n")
      @dialog_view.vadjustment.value = @dialog_view.vadjustment.upper - @dialog_view.vadjustment.step_increment
    rescue
      RsInfobox.new(self, "#{$!}", "error")
    end
  end
  
  def send_start_typing
    @ns.sock_send(NetSoul::Message.start_writing_to_user(@login))
    @send_typing = true
  end
  
  def send_stop_typing
    @ns.sock_send(NetSoul::Message.stop_writing_to_user(@login))
    @send_typing = false
  end
  
  def print_user_typing_status
    set_status(@ctx_user_typing_id, "#{@login} is typing...")
  end
  
  def print_init_status
    set_status(@ctx_init_id, "#{RsConfig::APP_NAME} #{RsConfig::APP_VERSION}")
  end
  
  def set_status(ctx_id, msg)
    @statusbar.pop(@ctx_current_id) if @ctx_current_id
    @statusbar.push(ctx_id, msg.to_s)
    @ctx_current_id = ctx_id
  end
end

