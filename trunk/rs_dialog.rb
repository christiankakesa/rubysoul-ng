=begin
  Made by Christian KAKESA etna_2008(paris) <christian.kakesa@gmail.com>
=end

begin
	require 'gtk2'
	require 'rs_config'
rescue LoadError
	puts "Error: #{$!}"
	exit
end

class RsDialog < Gtk::Window
	attr_accessor :msg_view_buffer, :msg_view, :msg_send_buffer, :msg_send_view, :user_img_view

	def initialize(parent, ns, login, pix_path, state)
		super(login.to_s)
		set_icon(Gdk::Pixbuf.new(pix_path))
		vbox = Gtk::VBox.new
		set_title(login.to_s)
		set_modal(false)
		set_destroy_with_parent(true)
		@ns = ns
		@login = login
 		@msg_view_buffer = Gtk::TextBuffer.new
		@msg_view = Gtk::TextView.new(@msg_view_buffer)
		@msg_view_scroll = Gtk::ScrolledWindow.new().add(@msg_view)
		@msg_send_buffer = Gtk::TextBuffer.new
		@msg_send_view = Gtk::TextView.new(@msg_send_buffer)
		@msg_send_view_scroll = Gtk::ScrolledWindow.new().add(@msg_send_view)
		@user_img_view = Gtk::Image.new(Gdk::Pixbuf.new(pix_path.to_s, 128, 128))
		vbox.pack_start(Gtk::Frame.new("Dialog").add(@msg_view_scroll), false, false)
		vbox.pack_start(Gtk::Frame.new("Message").add(@msg_send_view_scroll), false, true)
		vbox.pack_start(Gtk::Frame.new("User image").add(@user_img_view), false, true)
		add(vbox)
		signal_connect('delete-event') do |me, ev|
			me.hide_all
		end

	end

	def send_msg(msg)
		@ns.sock_send(NetSoul::Message.send_message(@login.to_s, msg.to_s))
		@msg_send_buffer.empty!
		@msg_view_buffer.text += %Q[<span color="blue">\n\[#{time.now.to_s}\] #{msg.to_s}</span>]
	end

	def receive_msg(msg)
		@msg_view_buffer.text += %Q[<span color="red">\n\[#{time.now.to_s}\] #{msg.to_s}</span>]
	end
end
