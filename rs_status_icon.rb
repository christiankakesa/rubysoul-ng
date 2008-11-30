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

class RsStatusIcon < Gtk::StatusIcon

  def initialize(main_app, parent_win = nil)
    super()
    @main_app = main_app
    @parent_win = parent_win
    build_status_icon()

    signal_connect("activate") do |w|
      unless @parent_win.visible?
        @parent_win.show_all()
      else
        if @parent_win.active?
          @parent_win.hide_all()
        else
          @parent_win.present()
        end
      end
    end
    signal_connect("popup-menu") do |widget, button, activate_time|
      menu = Gtk::Menu.new
      menuitem = Gtk::ImageMenuItem.new(Gtk::Stock::CONNECT)
      menuitem.signal_connect("activate"){|w|
        @main_app.on_tb_connect_clicked(w)
      }
      menu.append(menuitem)

      menuitem = Gtk::ImageMenuItem.new(Gtk::Stock::DISCONNECT)
      menuitem.signal_connect("activate"){|w|
        @main_app.on_tb_connect_clicked(w)
      }
      menu.append(menuitem)
      
      menu.append(Gtk::SeparatorMenuItem.new)

      menuitem = Gtk::ImageMenuItem.new(Gtk::Stock::ADD)
      menuitem.child().set_label("C_ontacts")
      menuitem.signal_connect("activate"){|w|
        @main_app.on_tb_contact_clicked(w)
      }
      menu.append(menuitem)

      menuitem = Gtk::ImageMenuItem.new(Gtk::Stock::PREFERENCES)
      menuitem.signal_connect("activate"){|w|
        @main_app.on_tb_preferences_clicked(w)
      }
      menu.append(menuitem)
      
      menu.append(Gtk::SeparatorMenuItem.new)

      menuitem = Gtk::ImageMenuItem.new(Gtk::Stock::ABOUT)
      menuitem.child().set_label("_Informations")
      menuitem.signal_connect("activate"){|w|
        @main_app.on_tb_about_clicked(w)
      }
      menu.append(menuitem)

			menu.append(Gtk::SeparatorMenuItem.new)
			
      menuitem = Gtk::ImageMenuItem.new(Gtk::Stock::CLOSE)
      menuitem.signal_connect("activate"){
        set_visible(false)
        @main_app.on_statusicon_delete_event()
      }
      menu.append(menuitem)

      menu.show_all
      menu.popup(nil, nil, button, activate_time)
    end
  end

  def build_status_icon
    #set_icon_name(Gtk::Stock::DIALOG_INFO)
    set_pixbuf(Gdk::Pixbuf.new("#{RsConfig::APP_DIR+File::SEPARATOR}logo.png"))
    set_tooltip("#{RsConfig::APP_NAME} #{RsConfig::APP_VERSION}")
    set_visible(true)
  end
end

