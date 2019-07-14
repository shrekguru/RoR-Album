require 'redis'

module Import
  class Spotify
    def initialize(refresh_token)
      uri = URI.parse(ENV['REDISCLOUD_URL'])
      @redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
      refresh_token = @redis.get('spotify:refresh_token') || ENV['SPOTIFY_REFRESH_TOKEN']
      @access_token = get_access_token(refresh_token)
    end

    def get_albums
      items = []
      ['short_term', 'medium_term', 'long_term'].each do |r|
        items = get_top_tracks(r)
        break unless items.empty?
      end
      File.open('data/spotify.json','w'){ |f| f << items.to_json }
    end

    def get_top_tracks(time_range)
      url = "https://api.spotify.com/v1/me/top/tracks?limit=50&time_range=#{time_range}"
      response = HTTParty.get(url, headers: { 'Authorization': "Bearer #{@access_token}" })
      items = []
      if response.code == 200
        items = JSON.parse(response.body)['items']
        items = items.group_by { |i| i['album']['name'] }
                     .values
                     .slice(0, ENV['SPOTIFY_COUNT'].to_i)
                     .map { |i| get_spotify_data(i[0]['album']['href']) }
                     .reject { |i| i.nil? } unless items.empty?
      end
      items
    end

    def get_spotify_data(album_url)
      response = HTTParty.get(album_url, headers: { 'Authorization': "Bearer #{@access_token}" })
      if response.code == 200
        data = JSON.parse(response.body)
        album = {
          id: data['id'],
          name: unclutter_album_name(data['name']),
          url: data['external_urls']['spotify'],
          artists: data['artists'].map { |a| format_artist(a) },
          image_url: data['images'][0]['url'],
          release_date: data['release_date'],
          release_date_precision: data['release_date_precision'],
          genres: data['genres']
        }
        File.open("source/images/spotify/#{album[:id]}.jpg",'w'){ |f| f << HTTParty.get(album[:image_url]).body }
        album
      else
        nil
      end
    end

    def format_artist(artist)
      {
        id: artist['id'],
        name: artist['name'],
        url: artist['external_urls']['spotify']
      }
    end

    # Remove shit like [remastered] and (deluxe version) or whatever from album names
    def unclutter_album_name(album)
      album.gsub(/\[[\w\s]+\]/,'').strip.gsub(/\([\w\s-]+\)$/,'').strip
    end

    def get_access_token(refresh_token)
      body = {
        grant_type: 'refresh_token',
        refresh_token: refresh_token,
        redirect_uri: ENV['SITE_URL'],
        client_id: ENV['SPOTIFY_CLIENT_ID'],
        client_secret: ENV['SPOTIFY_CLIENT_SECRET']
      }
      response = HTTParty.post('https://accounts.spotify.com/api/token', body: body)
      if response.code ==  200
        response_body = JSON.parse(response.body)
        @redis.set('spotify:refresh_token', response_body['refresh_token']) unless response_body['refresh_token'].nil?
        access_token = response_body['access_token']
      else
        access_token = nil
      end
      access_token
    end
  end
end