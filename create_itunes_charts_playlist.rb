#!/usr/bin/env ruby

require 'open-uri'
require 'nokogiri'
require 'spotify'

require_relative 'item'
require_relative "support"

items = Array.new

itunes_rss_url = 'https://itunes.apple.com/us/rss/topalbums/limit=10/genre=7/explicit=true/xml'

puts "Retrieving list of albums from iTunes"
open(itunes_rss_url) do |rss|
	feed = Nokogiri::XML(rss)
	entries = feed.xpath("//xmlns:entry")
	entries.each do |entry|
		artist = entry.xpath('im:artist').text
		album = entry.xpath('im:name').text
		items.push(Item.new(artist, album))
	end
end

puts "Updating Spotify"
spotify_config = {
	api_version: Spotify::API_VERSION.to_i,
	application_key: File.binread("./spotify_appkey.key"),
	cache_location: ".spotify/",
	settings_location: ".spotify/",
	user_agent: "spotify for ruby",
	callbacks: Spotify::SessionCallbacks.new
}

error, session = Spotify.session_create(spotify_config)
raise error if error.is_a?(Spotify::APIError)

username = Support.prompt("Spotify username")
password = $stdin.noecho { Support.prompt("Spotify password") }
Spotify.try(:session_login, session, username, password, true, nil)

Support.poll(session) { Spotify.session_connectionstate(session) == :logged_in }

puts "Creating Spotify playlist"

playlist_container = Spotify.session_playlistcontainer(session)
playlist = Spotify.playlistcontainer_add_new_playlist(playlist_container, "iTunes Top Electronic")

playlist_index = 0

items.each do |item|
	search_query = item.artist + " " + item.album
	puts "Searching for #{search_query}"
	search = Spotify.search_create(session, search_query, 0, 10, 0, 10, 0, 10, 0, 10, :standard, proc {}, nil)
	Support.poll(session) { Spotify.search_is_loaded(search) }
	
	album_count = Spotify.search_total_albums(search).to_i
	puts "Found #{album_count} albums"

	if album_count > 0

		album = Spotify.search_album(search, 0)		
		album_browse = Spotify.albumbrowse_create(session, album, proc {}, nil)
		Support.poll(session) { Spotify.albumbrowse_is_loaded(album_browse) }
		
		track_count = Spotify.albumbrowse_num_tracks(album_browse).to_i
		puts "Found #{track_count} tracks"

		(0..track_count).each do |index|
			track = Spotify.albumbrowse_track(album_browse, index)
			if !track.nil?
				puts "Adding " + Spotify.track_name(track) + "to playlist"
				Spotify.playlist_add_tracks(playlist, track, playlist_index, session)
				playlist_index = playlist_index + 1
			end
		end

	else
		puts "No matches found"
		next
	end
end
