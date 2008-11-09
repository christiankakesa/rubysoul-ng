=begin
  Made by Christian KAKESA etna_2008(paris) <christian.kakesa@gmail.com>
=end

begin
  require 'gtk2'
  require 'rs_config'
  require 'rs_infobox'
rescue LoadError
  puts "Error: #{$!}"
  exit
end

class UserView < Gtk::ScrolledWindow
  attr_accessor :contacts, :users_dialog

  def initialize(parent_win, contact_array, ns)
    super()
    set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_AUTOMATIC)
    @parent_win = parent_win
    @contacts = contact_array
    @user_dialogs = Hash.new
    @photo_dir = File.dirname(__FILE__) + File::SEPARATOR + "images" + File::SEPARATOR + "contacts" + File::SEPARATOR
    @user_model = Gtk::TreeStore.new(Gdk::Pixbuf, String, Gdk::Pixbuf, String, String, String)
    @user_model.set_sort_column_id(1)
    @pix_status_renderer = Gtk::CellRendererPixbuf.new
    @pix_status_renderer.set_xalign(0.5)
    @pix_status_renderer.set_yalign(0.0)
    @nstr_ll_renderer = Gtk::CellRendererText.new
    @nstr_ll_renderer.set_alignment(Pango::ALIGN_LEFT)
    @nstr_ll_renderer.set_wrap_mode(Pango::Layout::WRAP_CHAR)
    @pix_photo_renderer = Gtk::CellRendererPixbuf.new
    @pix_photo_renderer.set_xalign(0.0)
    @pix_photo_renderer.set_yalign(0.0)
    @nstatus_column = Gtk::TreeViewColumn.new("Status", @pix_status_renderer, :pixbuf => 0)
    @nstatus_column.set_min_width(24)
    @login_ll_column = Gtk::TreeViewColumn.new("Login / Location", @nstr_ll_renderer, :markup => 1)
    @login_ll_column.set_min_width(186)
    @photo_column = Gtk::TreeViewColumn.new("Photo", @pix_photo_renderer, :pixbuf => 2)
    @photo_column.set_min_width(32)
    @tv = Gtk::TreeView.new(@user_model)
    @tv.append_column(@nstatus_column)
    @tv.append_column(@login_ll_column)
    @tv.append_column(@photo_column)
    @tv.headers_visible = false
    @tv.reorderable = true
    @tv.signal_connect("row-activated") do |view, path, column|
      if (ns.connected)
        get_user_dialog(ns, view.model.get_iter(path)[3], view.model.get_iter(path)[4], @photo_dir + view.model.get_iter(path)[3].to_s, view.model.get_iter(path)[5]).show_all
      else
        RsInfobox.new(@parent_win, "You are not connected. No dialog box available", "warning")
      end
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

  def get_user_dialog(ns, login, socket_id, pix_path, state)
    puts "user_login == #{login}"
    puts "user_socket_id == #{socket_id}"
    puts "user_pix_path == #{pix_path}"
    puts "user_status == #{state}"
    if not (@user_dialogs.has_key?(login.to_s))
      @user_dialogs[login.to_s] = RsDialog.new(self, ns, login, pix_path, state)
    end
    return @user_dialogs[login.to_s]
  end

  def add_user_status(login, socket, status)
    @user_model.each do |model,path,iter|
      if (iter[3].to_s == login.to_s)
        if (@contacts[login.to_s].include?(:state))
          iter.set_value(0, Gdk::Pixbuf.new(get_status_icon(status.to_s), 24, 24))
=begin
          @contacts[login.to_s][:state].each do |sock, value|
            if (socket.to_s == sock.to_s)
              it = @user_model.append(iter)
              it.set_value(0, Gdk::Pixbuf.new(get_status_icon(value[:status].to_s), 24, 24))
              l = value[:status].to_s + "@" + value[:location].to_s
              it.set_value(1, %Q[<span weight="normal" size="small">#{l}</span>])
              it.set_value(2, nil)
              it.set_value(3, login.to_s)
              it.set_value(4, sock.to_s)
              it.set_value(5, value[:status].to_s)
            end
          end
=end
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
      if (!v.nil? && v.include?(:state))
        @contacts[k.to_s].delete(:state)
      end
    end
    fill_treeview()
  end
end

