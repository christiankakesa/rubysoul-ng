=begin
  Made by Christian KAKESA etna_2008(paris) <christian.kakesa@gmail.com>
=end

begin
  require 'gtk2'
rescue LoadError
  puts "Error: #{$!}"
  exit
end

class RsInfobox
  def initialize(main_app_window, message, type = "info", modal = true)
    info_type = Gtk::MessageDialog::OTHER
    info_button = Gtk::MessageDialog::BUTTONS_CLOSE
    case type.to_s
    when "error"
      info_type = Gtk::MessageDialog::ERROR
    when "info"
      info_type = Gtk::MessageDialog::INFO
      info_button = Gtk::MessageDialog::BUTTONS_OK
    when "question"
      info_type = Gtk::MessageDialog::QUESTION
      info_button = Gtk::MessageDialog::BUTTONS_YES_NO
    when "warning"
      info_type = Gtk::MessageDialog::WARNING
      info_button = Gtk::MessageDialog::BUTTONS_OK
    end
    infobox = Gtk::MessageDialog.new(main_app_window, (modal ? Gtk::Dialog::MODAL : Gtk::Dialog::DESTROY_WITH_PARENT), info_type, info_button, message.to_s)
=begin
    if modal
      infobox = Gtk::MessageDialog.new(main_app_window, Gtk::Dialog::MODAL, info_type, info_button, message.to_s)
    else
      infobox = Gtk::MessageDialog.new(main_app_window, Gtk::Dialog::DESTROY_WITH_PARENT, info_type, info_button, message.to_s)
    end
=end
    infobox.run()
    infobox.destroy()
  end
end

