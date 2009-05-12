require 'trimet_api'
require 'cgi'
require 'sinatra'

configure do
  APPID = ENV['TRIMET_APPID']
  SECRET = ENV['BUSCATCHER_SECRET']
  TRIMET = TrimetAPI::Connection.new(APPID)
  mime :json, "application/json"
end

helpers do

end

get '/' do
  lat = params[:lat].to_f
  lng = params[:lng].to_f
  acc = params[:acc].to_f
  if lat == 0.0 or lng == 0.0
    haml :where_are_you
  else
    @here = [lat, lng]
    @now = Time.now
    @accuracy = acc
    @stops = TrimetAPI::Stop.near(lat, lng, 400 + acc).limit(15).sort_by { |s| s.distance_from(*@here) }
    @arrivals = TRIMET.arrivals_for(@stops).sort_by { |a| a.estimated || a.scheduled }

    # Filter out arrival times for lines that have arrival times listed for a closer stop
    marked_lines = []
    @stops.each do |stop|
      @arrivals.reject! { |a| a.stop == stop and marked_lines.include?(a.direction) }
      marked_lines += @arrivals.select { |a| a.stop == stop }.map { |a| a.direction }
    end

    # Filter out stops that are not going to have any arrival times listed
    @stops.reject! do |stop|
      @arrivals.select { |a| a.stop == stop }.empty?
    end

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

get '/stops.:format' do
  lat = params[:lat].to_f
  lng = params[:lng].to_f
  dist = (params[:dist] || 400).to_f
  @stops = TrimetAPI::Stop.near(lat, lng, dist).sort_by { |s| s.distance_from(lat, lng) }
  if @stops && !@stops.empty?
    case params[:format]
    when 'json'
      content_type :json
      @stops.map { |s| s.to_json }.to_json
    else
      pass
    end
  else
    pass
  end
end

post '/reload_routes_and_stops' do
  secret = params[:secret]
  if secret == SECRET
    TRIMET.load_routes_and_stops
    'success'
  else
    halt 403, 'Forbidden Action'
  end
end

use_in_file_templates!

__END__

@@ where_are_you
%h1 Where are you?
%form{ :action => "/location", :method => :post }
  %input{ :type => "text", :name => "location", :size => "30" }
  %input{ :type => "submit", :name => "commit", :value => "  find nearby stops  " }
#searching{ :style => "display:none" }
  %h2 Trying to find your location...
#your-location{ :style => "display:none" }
  %h2 Found your location
  %p
    Found your location within
    %span.accuracy
    meters:
  %p
    %a.results-link
#location-not-found{ :style => "display:none" }
  %h2 Could not find your location
  %p
    Could not find your location with a margin-of-error of less than
    %span.accuracy
    meters. Please enter an address above.
#error{ :style => "display:none"}
  %h2
    An error occurred
  %p.message
%script{ :type => "text/javascript", :src => "/jquery-1.2.6.pack.js" }
%script{ :type => "text/javascript", :src => "/gears_init.js" }
%script{ :type => "text/javascript", :src => "/locator.js" }


@@ no_results
%h1 No stops found near your location!


@@ arrival_times
%h1== Stops near #{html_escape @title}
%table
  %tbody
    - @stops.each do |stop|
      %tr
        %td{ :colspan => "3" }
          == #{html_escape stop.desc} StopID: #{html_escape stop.locid} distance: #{html_escape stop.pretty_distance_from(*(@here + [@accuracy]))}
      - @arrivals.select { |a| a.stop == stop }.each do |arrival|
        %tr
          %td &nbsp;
          %td= html_escape arrival.short_sign
          - if arrival.estimated
            %td
              %b= arrival.time_remaining
          - else
            %td.relativize= arrival.scheduled
%script{ :type => "text/javascript", :src => "/jquery-1.2.6.pack.js" }
%script{ :type => "text/javascript", :src => "/relativize.js" }


@@ layout
!!! XML
!!! 1.1
%html{ :xmlns => "http://www.w3.org/1999/xhtml", 'xml:lang'.to_sym => "en" }
  %head
    %title= [html_escape(@title), 'sitr.us/buscatcher'].reject { |e| e.empty? }.join(' - ')
  %body
    = yield

