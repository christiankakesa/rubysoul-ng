=begin
  Developpers  : Christian KAKESA etna_2008(paris) <christian.kakesa@gmail.com>
=end
begin
	require 'gtk2'
	require 'rs_config'
rescue LoadError
	puts "Error: #{$!}"
	exit
end

class RsAbout < Gtk::AboutDialog
	def initialize
		super
	end
end
