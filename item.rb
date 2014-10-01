class Item
	attr_accessor :artist
	attr_accessor :album

	def initialize(artist, album)
		@artist = artist
		@album = album
	end
end