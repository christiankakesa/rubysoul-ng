=begin
  Made by Christian KAKESA etna_2008(paris) <christian.kakesa@gmail.com>
=end

begin
  require 'gtk2'
  require 'rs_contact'
rescue LoadError
  puts "Error: #{$!}"
  exit
end

class RsTooltip < Gtk::Tooltips
  def initialize(parent_widget = nil)
    super()
    @current_iter = nil
    @parent_widget = parent_widget
    @contacts = RsContact::instance()
    if @parent_widget
      @parent_widget.signal_connect("motion-notify-event") do |widget, event|
        path, column, x, y = @parent_widget.get_path_at_pos(event.x, event.y)
        if !path.nil?()
          iter = @parent_widget.model.get_iter(path)
          if (@parent_widget.model.iter_is_valid?(iter) && !(@current_iter == iter))
          	if (!iter.has_child?() && iter.parent().nil?() && iter[3].to_s != "zzzzzz_z") 
          		set_tip(@parent_widget, build_text(iter), nil)
            elsif (iter.has_child?() && iter.parent().nil?() && iter[3].to_s != "zzzzzz_z")
            	child = iter.first_child
          		set_tip(@parent_widget, build_all_text(child), nil)
            elsif iter[3].to_s == "zzzzzz_z"
            	set_tip(@parent_widget, 'Offline contacts', nil)
            else
            	set_tip(@parent_widget, "#{iter[3].to_s.upcase}", nil)
            end
            @current_iter = iter
          end
        end
      end
    end
  end
  
  def build_text(iter)
    res  = "#{iter[3].to_s.upcase()}\n"
    res += "Session   : #{iter[4].to_s}\n"
    res += "Status    : #{iter[5].to_s}\n"
    res += "User data : #{iter[6].to_s}\n"
    res += "Location  : #{iter[7].to_s}"
    return res
  end
  def build_all_text(iter)
  	res  = "#{iter[3].to_s.upcase()}\n"
  	res += "Session   : #{iter[4].to_s}\n"
    res += "Status    : #{iter[5].to_s}\n"
    res += "User data : #{iter[6].to_s}\n"
    res += "Location  : #{iter[7].to_s}\n"
    res += "----------\n"
  	while iter.next!
		  res += "Session   : #{iter[4].to_s}\n"
		  res += "Status    : #{iter[5].to_s}\n"
		  res += "User data : #{iter[6].to_s}\n"
		  res += "Location  : #{iter[7].to_s}\n"
		  res += "----------\n"
    end
    return res
  end
end

