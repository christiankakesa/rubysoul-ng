=begin
  Made by Christian KAKESA etna_2008(paris) <christian.kakesa@gmail.com>
=end

module NetSoul
class Location
	def self.get(ip)
	  res = nil
		data = {"lab-cisco-mid-sr"	=> "10.251.",
				"etna"				=> "10.245.",
				"lse"				=> "10.227.42.",
				"sda"				=> "10.227.4.",
				"lab"				=> "10.227.",
				"lab-tcom"			=> "10.226.7.",
				"lab-acu"			=> "10.226.6.",
				"lab-console"		=> "10.226.5.",
				"lab-mspe"			=> "10.226.",
				"epitanim"			=> "10.225.19.",
				"epidemic"			=> "10.225.18.",
				"sda"				=> "10.225.10.",
				"cycom"				=> "10.225.8.",
				"epx"				=> "10.225.7.",
				"prologin"			=> "10.225.6.",
				"nomad"				=> "10.225.2.",
				"assos"				=> "10.225.",
				"sda"				=> "10.224.14.",
				"www"				=> "10.223.106.",
				"episport"			=> "10.223.104.",
				"epicom"			=> "10.223.103.",
				"bde-epita"			=> "10.223.100.",
				"omatis"			=> "10.223.42.",
				"ipsa"				=> "10.223.15.",
				"lrde"				=> "10.223.13.",
				"cvi"				=> "10.223.7.",
				"epi"				=> "10.223.1.",
				"pasteur"			=> "10.223.",
				"bocal"				=> "10.42.42.",
				"sm"				=> "10.42.",
				"vpn"				=> "10.10.",
				"adm"				=> "10.1.",
				"epita"				=> "10."	}
		data.each do |key, val|
			res = ip.match(/^#{val}/)
			if res
				res = "#{key}".chomp
				return res
			end
		end
		return res
	end
end
end #--- | module RubySoul

