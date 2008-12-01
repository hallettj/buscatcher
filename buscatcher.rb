require 'rubygems'
require 'trimet_api'
require 'sinatra'

configure do
  APPID = File.open('appid.txt','r') { |f| f.read.strip }
  TRIMET = TrimetAPI::Connection.new(APPID)
  #  TRIMET.load_routes_and_stops
end

helpers do

end

get '/' do
  lat = params[:lat].to_f
  lng = params[:lng].to_f
  if lat == 0.0 or lng == 0.0
    haml :where_are_you
  else
    @stops = TrimetAPI::Stop.near(lat, lng).limit(10).sort_by { |stop|
      Math.sqrt((stop.lat - lat).abs ** 2 + (stop.lng - lng).abs ** 2)
    }
    @arrivals = TRIMET.arrivals_for(@stops).sort_by { |a| a.estimated || a.scheduled }
    @here = [lat, lng]
    @now = Time.now
=begin
  @stops = TrimetAPI::Stop.near(lat, lng).limit(5).by_distance_from(lat, lng)
=end
    if @stops.empty?
      haml :no_results
    else
      @title = @stops.first.desc
      haml :arrival_times
    end
  end
end

post '/location' do
  lat, lng = RestClient.get('http://tinygeocoder.com/create-api.php?q=' + CGI.escape(params[:location].to_s)).split(',')
  redirect "/?lat=#{lat}&lng=#{lng}", "You have been redirected."
end

use_in_file_templates!

__END__

@@ where_are_you
%h1 Where are you?
%form{ :action => "/location", :method => :post }
  %input{ :type => "text", :name => "location", :size => "30" }
  %input{ :type => "submit", :name => "commit", :value => "  find nearby stops  " }
%script{ :type => "text/javascript", :src => "/gears_init.js" }
%script{ :type => "text/javascript" }
  if (window.google && google.gears) {
  var geo = google.gears.factory.create('beta.geolocation');
  var positionOptions = { enableHighAccuracy: true };
  function updatePosition(position) { window.location = '/?lat=' + position.latitude + '&lng=' + position.longitude; }
  geo.getCurrentPosition(updatePosition, null, positionOptions);
  }


@@ no_results
%h1 No stops found near your location!


@@ arrival_times
%h1== Stops near #{html_escape @title}
%ul
  - @stops.each do |stop|
    %li
      == #{html_escape stop.desc} StopID: #{html_escape stop.locid} distance: #{html_escape stop.distance_from(*@here)}
      %ul
        - @arrivals.select { |a| a.stop == stop }.each do |arrival|
          %li
            = html_escape arrival.full_sign
            - if arrival.estimated
              arriving in 
              %b= arrival.time_remaining
            - else
              == scheduled at #{arrival.scheduled}


@@ layout
!!! XML
!!! 1.1
%html{ :xmlns => "http://www.w3.org/1999/xhtml", 'xml:lang'.to_sym => "en" }
  %head
    %title= [html_escape(@title), 'sitr.us/buscatcher'].reject { |e| e.empty? }.join(' - ')
  %body
    = yield

