require 'degrees'
require 'rubygems'
require 'data_mapper'

class Aerodrome

  include DataMapper::Persistence

  property :name, :string
  property :icao_code, :string
  property :certification, :string
  property :latitude, :float
  property :longitude, :float

  EARTH_RADIUS = 3438.461 # nautical miles

  def distance_to(to_ad)
    (Aerodrome.distance_between(self, to_ad) * 100).round / 100.0
  end
 
  alias_method :distance_from, :distance_to

  # http://en.wikipedia.org/wiki/Great-circle_distance#The_geographical_formula
  def self.distance_between(from, to, options={})
    return 0.0 if from == to # fixes a "zero-distance" bug

    slat = from.latitude.radians
    slng = from.longitude.radians
    flat = to.latitude.radians
    flng = to.longitude.radians
    dlng = (slng - flng).abs

    EARTH_RADIUS * Math.atan(
      Math.sqrt(
        (Math.cos(flat) * Math.sin(dlng))**2 +
        (
          (Math.cos(slat) * Math.sin(flat)) -
          (Math.sin(slat) * Math.cos(flat) * Math.cos(dlng))
        )**2
      ) /
      (
        (Math.sin(slat) * Math.sin(flat)) +
        (Math.cos(slat) * Math.cos(flat) * Math.cos(dlng))
      )
    )
  end

  def inspect
    (icao_code || "    ") + " " +
    name + " " +
    "(#{certification})"
  end

end
