require 'rest_client'
require 'xmlsimple'
require 'dm-core'
require 'dm-aggregates'

RestClient.proxy = ENV['http_proxy']
#DataMapper.setup(:default, "sqlite3::memory:")
DataMapper.setup(:default, "mysql://localhost/buscatcher_development")

module TrimetAPI

  class Line
    include DataMapper::Resource
    property :id,    Integer, :serial => true
    property :desc,  String
    property :route, String
    property :type,  String
    has n, :directions
    has n, :stops,    :through => :directions
    has n, :arrivals, :through => :directions
  end

  class Direction
    include DataMapper::Resource
    property :id,   Integer, :serial => true
    property :dir,  String
    property :desc, String
    belongs_to :line
    #    has n, :stops, :through => Resource, :class_name => "::TrimetAPI::Stop", :child_key => [:stop_id]
    has n, :stoppings
    has n, :stops, :through => :stoppings
    has n, :arrivals
  end

  class Stop
    include DataMapper::Resource
    property :id,    Integer, :serial => true
    property :locid, String
    property :desc,  String
    property :lat,   Float
    property :lng,   Float
    property :seq,   Integer
    property :tp,    Boolean
    #    has n, :directions, :through => Resource, :class_name => "::TrimetAPI::Direction", :child_key => [:direction_id]
    has n, :stoppings
    has n, :directions, :through => :stoppings
    has n, :lines,      :through => :directions
    has n, :arrivals

    METERS_PER_DEGREE = 111132.09
    METERS_PER_MILE   =   1609.344

    # Returns all stops within +epsilon+ meters of a given point expressed as a latitude and longitude
    def self.near(lat, lng, epsilon=400)
      all :conditions => ["sqrt(pow(#{METERS_PER_DEGREE} * (lat - ?), 2) + 
                                pow(#{METERS_PER_DEGREE} * (lng - ?) * cos((lat * 2.0 * PI()) / 360.0), 2)) <= ?",
                          lat, lng, epsilon]
    end

    def self.by_distance_from(lat, lng)
      all :order => ["sqrt(pow(11132.09 * (lat - ?), 2) + pow(11132.09 * (lng - ?) * cos((lat * 2.0 * PI()) / 360.0), 2))", 
                      lat, lng, epsilon]
    end

    def self.limit(num)
      all :limit => num
    end

    # Returns distance in meters between the stop and a given point expressed as a latitude and longitude
    def distance_from(latitude, longitude)
      delta_phi    = METERS_PER_DEGREE * (lat - latitude)
      delta_lambda = METERS_PER_DEGREE * (lng - longitude) * Math.cos((lat * 2.0 * Math::PI) / 360.0)
      Math.sqrt(delta_phi ** 2 + delta_lambda ** 2)
    end

    # Given the geocode of a starting point, returns a string describing the distance to this stop in miles
    def pretty_distance_from(latitude, longitude, accuracy=0)
      #"%0.2f miles" % (distance_from(latitude, longitude) / METERS_PER_MILE)
      distance = "%0.0f meters" % distance_from(latitude, longitude)
    end
  end

  # TODO: get rid of this model and use 'has n, :through => Resource' instead
  class Stopping
    include DataMapper::Resource
    property :id, Serial
    belongs_to :direction
    belongs_to :stop
  end

  class Arrival
    include DataMapper::Resource
    property :id,         Serial
    property :block,      Integer
    property :departed,   Boolean
    property :estimated,  Time
    property :full_sign,  String
    property :piece,      String
    property :scheduled,  Time
    property :short_sign, String
    property :status,     String
    property :detour,     Boolean
    belongs_to :stop
    belongs_to :direction
    belongs_to :line, :through => :direction

    def time_remaining
      return nil if estimated.nil?
      minutes = ((estimated - Time.now) / 60.0).floor
      if minutes > 0
        "#{minutes} minutes"
      else
        "due"
      end
    end
  end

  class Connection
    attr_accessor :app_id

    def initialize(app_id)
      @app_id = app_id
    end

    def load_routes_and_stops(options={})
      query = {
        :dir   => TrimetAPI.dir(options[:dir] || :all),
        :stops => (options[:stops] ? options[:stops].join(',') : 'all'),
        :appID => @app_id
      }
      xml = get_xml((["http://developer.trimet.org/ws/V1/routeConfig"] + query.to_a).join("/"))

      # Stops are listed by route. So iterate through each route to
      # load all the stops.
      xml["route"].each do |route|
        line = Line.first(:route => route["route"]) || Line.new
        line.attributes = { :desc => route["desc"], :route => route["route"], :type => route["type"] }
        line.save

        # Stops are further organized by direction, either "inbound" or "outbound"
        route["dir"].each do |dir|
          direction = line.directions.first(:dir => dir["dir"]) || line.directions.build
          direction.attributes = { :dir => dir["dir"], :desc => dir["desc"] }
          direction.save

          # Finally, iterate through stops. Note that not every 'dir' node in the XML document from Trimet has 'stop' nodes.
          (dir["stop"] || []).each do |s|
            stop = Stop.first(:locid => s["locid"]) || Stop.new
            stop.attributes = {
              :locid => s["locid"],
              :desc  => s["desc"],
              :lat   => s["lat"].to_f,
              :lng   => s["lng"].to_f,
              :seq   => s["seq"].to_i,
              :tp    => (s["tp"] == "true")
            }
            stop.save
            direction.stoppings.first(:stop_id => stop.id) || direction.stoppings.create(:stop => stop)
#            direction.stoppings.first_or_create(:stop_id => stop.id)
#            direction.stops << stop
          end

          direction.save
        end
      end

      return true
    end

    # Returns upcoming arrivals for the given stops. stops may be an array of TrimetAPI::Stop instances, a single instance, 
    # a single locid string, an array of locid strings, or an array of TrimetAPI::Stop instances and locid strings.
    def arrivals_for(stops)
      return [] if stops.nil? or stops.empty?
      query = {
        :locIDs => [stops].flatten.map { |s| s.is_a?(Stop) ? s.locid : s }.join(','),
        :appID => @app_id
      }
      xml = get_xml((["http://developer.trimet.org/ws/V1/arrivals"] + query.to_a).join("/"))

      if xml["errorMessage"]
        raise xml["errorMessage"].join("\n")
      end

      arrivals = xml["arrival"].map do |a|
        stop = Stop.first(:locid => a["locid"])
        line = Line.first(:route => a["route"])
        dir  = Direction.first(:dir => a["dir"], :line_id => line.id)
        Arrival.new(:stop       => stop,
                    :direction  => dir,
                    :line       => dir.line,
                    :block      => a["block"],
                    :departed   => (a["departed"] == "true"),
                    :estimated  => to_time(a["estimated"]),
                    :full_sign  => a["fullSign"],
                    :piece      => a["piece"],
                    :scheduled  => to_time(a["scheduled"]),
                    :short_sign => a["shortSign"],
                    :status     => a["status"],
                    :detour     => (a["detour"] == "true"))
      end
    end

    protected

    def get_xml(url)
      response = RestClient.get(url).to_s
      return XmlSimple.xml_in(response)
    end

    # Converts time from Trimet format into a Ruby object
    def to_time(milliseconds_since_epoch)
      return nil if milliseconds_since_epoch.nil? or milliseconds_since_epoch.empty?
      Time.at(milliseconds_since_epoch.to_i / 1000)
    end
  end

  # Given a string or a symbol representing a direction, returns the
  # API code for that direction.
  def self.dir(d)
    case d.to_s
    when "outbound", "0": 0
    when "inbound", "1": 1
    when "all", "true", "yes": "true"
    else
      nil
    end
  end

end

#DataMapper.auto_migrate!
