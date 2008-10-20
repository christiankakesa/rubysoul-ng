=begin
  Developpers  : Christian KAKESA etna_2008(paris) <christian.kakesa@gmail.com>
=end

begin
	require 'rs_window'
rescue LoadError
	puts "Error: #{$!}"
	exit
end

class RubySoulNG
  attr_reader :win
  
  def initialize
    win = MainFrame.new
    ## Layout perform ##
    ####################
    vbox = Gtk::VBox.new
    vbox.pack_start(win.menu, false, true)
    vbox.pack_start(Gtk::HSeparator.new, false, true)
    ## vbox.add(Gtk::Image.new(RS_IMG_BG))
    vbox.pack_start(win.user_view, true, true)
    vbox.pack_start(Gtk::HSeparator.new, false, true)
    vbox.pack_start(win.status_box, false, true)
    vbox.pack_start(Gtk::HSeparator.new, false, true)
    vbox.pack_end(win.status_bar, false, true)
    win.add(vbox)
    win.signal_connect("destroy") {win.quit()}
    ## MAIN LOOP APPLICATION ##
    ###########################
    win.show_all()
  end
end

### MAIN APPLICATION ###
########################
Gtk.init()
rs = RubySoulNG.new
Gtk.main()
