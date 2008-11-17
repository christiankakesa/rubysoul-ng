=begin
  Made by Christian KAKESA etna_2008(paris) <christian.kakesa@gmail.com>
=end

begin
  require 'gtk2'
rescue LoadError
  puts "Error: #{$!}"
  exit
end

class RsTooltip < Gtk::Window
  def initialize(parent_widget = nil, parent_win = nil)
    super(Gtk::Window::POPUP)
    set_decorated(false)
    set_resizable(false);
    set_border_width(4);
    set_app_paintable(true);
    @current_iter = nil
    @parent_widget = parent_widget
    @parent_win = parent_win
    @label_session = Gtk::Label.new
    @label_session.set_size_request(-1, -1)
    @label_session.set_wrap(true);
    @label_session.set_alignment(0.5, 0.5);
    @label_session.set_use_markup(true);
    @label_session.show();
    @label_status = Gtk::Label.new
    @label_status.set_size_request(-1, -1)
    @label_status.set_wrap(true);
    @label_status.set_alignment(0.5, 0.5);
    @label_status.set_use_markup(true);
    @label_status.show();
    @label_user_data = Gtk::Label.new
    @label_user_data.set_size_request(-1, -1)
    @label_user_data.set_wrap(true);
    @label_user_data.set_alignment(0.5, 0.5);
    @label_user_data.set_use_markup(true);
    @label_user_data.show();
    @label_location = Gtk::Label.new
    @label_location.set_size_request(-1, -1)
    @label_location.set_wrap(true);
    @label_location.set_alignment(0.5, 0.5);
    @label_location.set_use_markup(true);
    @label_location.show();
    add( Gtk::VBox.new().pack_start(@label_session, true, true).pack_start(@label_status, true, true).pack_start(@label_user_data, true, true).pack_end(@label_location, true, true) )
    if @parent_widget
      @parent_widget.signal_connect("motion-notify-event") do |widget, event|
        Gtk.queue do
          path, column, x, y = @parent_widget.get_path_at_pos(event.x, event.y)
          if path
            iter = @parent_widget.model.get_iter(path)
            if iter != @current_iter
              hide_all()
              if ( iter && iter[3].to_s != "zzzzzz_z" && iter[5] != "status")
                # if not visible?
                build_text(iter)
                #puts "X #{x} - Y: #{y}"
                move(event.x, event.y)
                show_all()
              end
            end
            @current_iter = iter
          end
        end
      end
      @parent_widget.signal_connect("leave-notify-event") do |widget, event|
        hide_all()
      end
    end
  end
  def build_text(iter)
    @label_session.set_markup("<tt><big>Session</big></tt>   : #{iter[4].to_s}")
    @label_status.set_markup("<tt><big>Status</big></tt>    : #{iter[5].to_s}")
    @label_user_data.set_markup("<tt><big>User data</big></tt> : #{iter[6].to_s}")
    @label_location.set_markup("<tt><big>Location</big></tt>  : #{iter[7].to_s}")
  end
end

