=begin
  Notebook de dialogue des users
=end
begin
  require 'coonfig'
rescue LoadError
end

class DialogChat < Gtk::Dialog
  attr_accessor :user_label, :msg_view_buffer, :msg_view, :msg_send_buffer, :msg_send_view, :user_img_view

  def initialize(parent_win, socket, user_login, user_socket_id, user_pix_path, user_status)
    super(user_login.to_s + '::' + user_socket_id.to_s,
          parent_win)
    self.set_modal(false)
    @socket = socket
    @user_label = Gtk::Label.new(%Q[<span weight="normal" size="large">#{user_login.to_s}</span>])
    @msg_view_buffer = Gtk::TextBuffer.new
    @msg_view = Gtk::TextView.new(@msg_view_buffer)
    @msg_view_scroll = Gtk::ScrolledWindow.new().add(@msg_view)
    @msg_send_buffer = Gtk::TextBuffer.new
    @msg_send_view = Gtk::TextView.new(@msg_send_buffer)
    @msg_send_view_scroll = Gtk::ScrolledWindow.new().add(@msg_send_view)
    @user_img_view = Gtk::Image.new(Gdk::Pixbuf.new(user_pix_path.to_s, 128, 128))
    self.vbox.packstart(Gtk::Frame.new("User login").set_size_request(250, 60).add(@user_label), false, false)
    self.vbox.packstart(Gtk::Frame.new("Dialog").add(@msg_view_scroll), false, false)
    self.vbox.packstart(Gtk::Frame.new("Message").add(@msg_send_view_scroll), false, true)
    self.vbox.packend(Gtk::Frame.new("User image").add(@user_img_view), false, true)
  end

  def send_msg(msg)
    @socket.send_msg(socket.to_s, msg.to_s)
    @msg_send_buffer.empty!
    @msg_view_buffer.text += %Q[<span color="blue">\n\[#{time.now.to_s}\] #{msg.to_s}</span>]
  end

  def receive_msg(msg)
    @msg_view_buffer.text += %Q[<span color="red">\n\[#{time.now.to_s}\] #{msg.to_s}</span>]
  end
end
