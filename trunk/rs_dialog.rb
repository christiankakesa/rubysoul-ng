=begin
  Made by Christian KAKESA etna_2008(paris) <christian.kakesa@gmail.com>
=end

begin
  require 'gtk2'
  require 'rs_config'
  require 'lib/netsoul'
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
    @ns = NetSoul::NetSoul::instance()
    set_icon(Gdk::Pixbuf.new("#{RsConfig::CONTACTS_PHOTO_DIR + File::SEPARATOR + @login}"))
    vbox = Gtk::VBox.new
    hbox = Gtk::HBox.new
    set_modal(false)
    set_destroy_with_parent(true)
    @dialog_buffer = Gtk::TextBuffer.new
    @dialog_view_tv = Gtk::TextView.new(@dialog_buffer)
    @dialog_view_tv.set_editable(false)
    @dialog_view_tv.set_wrap_mode(Gtk::TextTag::WRAP_WORD_CHAR)
    @dialog_view = Gtk::ScrolledWindow.new().add(@dialog_view_tv)
    @dialog_view.set_policy(Gtk::POLICY_NEVER, Gtk::POLICY_AUTOMATIC)
    @dialog_view.set_size_request(400, 200)
    @send_buffer = Gtk::TextBuffer.new
    @send_view_tv = Gtk::TextView.new(@send_buffer)
    @send_view_tv.set_wrap_mode(Gtk::TextTag::WRAP_WORD_CHAR)
    @send_view_tv.set_can_focus(true)
    @send_view = Gtk::ScrolledWindow.new().add(@send_view_tv)
    @send_view.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_AUTOMATIC)
    @user_img = Gtk::Image.new(Gdk::Pixbuf.new("#{RsConfig::CONTACTS_PHOTO_DIR + File::SEPARATOR + @login}", 128, 128))
    vbox.pack_start(@dialog_view, true, true, 3)
    hbox.pack_start(@send_view, true, true, 3)
    hbox.pack_end(@user_img, false, false, 3)
    vbox.pack_end(hbox, false, false, 3)
    add(vbox)
    set_focus_child(@send_view_tv)
    signal_connect('delete-event') do |widget, ev|
      widget.hide_all()
    end
    signal_connect("key-press-event") do |widget, event|
      case event.keyval
      when Gdk::Keyval::GDK_Return, Gdk::Keyval::GDK_KP_Enter, Gdk::Keyval::GDK_3270_Enter, Gdk::Keyval::GDK_ISO_Enter
        send_msg(@login, @send_buffer.text)
        @send_view_tv.set_focus(true)
      end
    end

  end

  def send_msg(user, msg)
    @ns.sock_send(NetSoul::Message::send_message(user.to_s, msg.to_s))
    @send_buffer.delete(@send_buffer.start_iter, @send_buffer.end_iter)
    @dialog_buffer.text += "(#{Time.now.strftime("%H:%M:%S")}) #{user.to_s}:"
    @dialog_buffer.text += " #{msg.to_s}\n"
  end

  def receive_msg(user_from, msg)
    @dialog_buffer.text += "(#{Time.now.strftime("%H:%M:%S")}) #{user_from.to_s}:"
    @dialog_buffer.text += " #{msg.to_s}\n"
  end
end

