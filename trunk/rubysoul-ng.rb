#!/usr/bin/ruby -w
=begin
  RSOULng.rb - Ruby/GTK NetSoul ETNA Client.
  Copyright (c) 2006 Christian KAKESA.
=end
begin
  require 'C_Frame'
rescue LoadError
end

class RSOULng
  attr_reader :win
  
  def initialize
    @@win = C_MainFrame.new
    ## Layout perform ##
    ####################
    vbox = Gtk::VBox.new
    vbox.pack_start(@@win.menu, false, true)
    vbox.pack_start(Gtk::HSeparator.new, false, true)
    ## vbox.add(Gtk::Image.new(RS_IMG_BG))
    vbox.pack_start(@@win.user_view, true, true)
    vbox.pack_start(Gtk::HSeparator.new, false, true)
    vbox.pack_start(@@win.status_box, false, true)
    vbox.pack_start(Gtk::HSeparator.new, false, true)
    vbox.pack_end(@@win.status_bar, false, true)
    @@win.add(vbox)
    @@win.signal_connect("destroy") {@@win.fQuit}
    ## MAIN LOOP APPLICATION ##
    ###########################
    @@win.show_all
  end
end

### MAIN APPLICATION ###
########################
Gtk.init
rs = RSOULng.new
Gtk.main
