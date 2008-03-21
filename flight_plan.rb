class Numeric

	def radians
		self * Math::PI/180
	end
	
	def degrees
		self * 180/Math::PI
	end
		
end

module FlightPlan

	ZERO_CELCIUS = 273.15 # degK
	ISA_SEA_LEVEL_TEMPERATURE = ZERO_CELCIUS + 15 # degK
	ISA_SEA_LEVEL_PRESSURE = 1013.25 # hPa
	ISA_SEA_LEVEL_SPEED_OF_SOUND = 661.47 # kt
	ISA_TROPOSPHERE = 36089.24 # ft
	
	class FlightPlanType
	
		attr_reader :fuel_units, :etd

		def initialize( fuel_units, etd )
			@fuel_units = fuel_units
			@legs = []
			@etd = Time.parse etd
		end
		
		def add_leg( leg )
			@legs << leg
		end
		
		def columns
		
			leg_eta = etd
			total_fuel = 0
			
			if fuel_units == :kg || fuel_units == :lbs
				round = true
			else
				round = false
			end
			
			@legs.collect do |leg|
				
				total_fuel = total_fuel + leg.zone_fuel if leg.zone_fuel
				
				if leg_eta and leg.time
					leg_eta = leg_eta + leg.time * 60
				else
					leg_eta = nil
				end
				
				[
					leg.from,
					leg.to,
					leg.altitude || '-',
					leg.cas || '-',
					leg.oat || '-',
					leg.tas || '-',
					leg.track ? "%03d" % leg.track : '-',
					leg.winddirection ? "#{"%03d" % leg.winddirection}/#{leg.windspeed}" : '-',
					leg.heading ? "%03d" % leg.heading : '-',
					leg.groundspeed || '-',
					leg.distance || '-',
					leg.time || '-',
					leg_eta ? leg_eta.strftime('%H:%M') : '-',
					leg.fuel_consumption || '-',
					round ? leg.zone_fuel.round : leg.zone_fuel,
					round ? total_fuel.round : total_fuel,
				]
			end
		end
		
		def contingency(percentage)
		
			total_flight_fuel = 0.0
		
			@legs.collect do |leg|
				
				next if leg.is_a? Reserve
				next if leg.is_a? Contingency
					
				total_flight_fuel = total_flight_fuel + leg.zone_fuel
					
			end
			
			c = Contingency.new percentage, (total_flight_fuel * percentage.to_f/100)
			add_leg c
		
		end
		
	end
	
	class IFRFlightPlan < FlightPlanType
	end
	
	class VFRFlightPlan < FlightPlanType
	end

	class Leg

		include Math

		attr_reader :from, :to, :altitude, :cas, :oat, :track, :winddirection, :windspeed, :distance, :fuel_consumption
	
		def initialize( from, to, altitude, metsector, variation, cas, track, distance, fuel_consumption )
		
			@from = from.to_s
			@to = to.to_s
			@altitude = altitude.to_i
			@cas = cas.to_i
			
			@metsector = metsector
			@forecast = @metsector.forecast(altitude, variation)
			
			@oat = @forecast.temperature
			@winddirection = @forecast.winddirection
			@windspeed = @forecast.windspeed
			
			@track = track.to_i
			@distance = distance.to_i
			
			@fuel_consumption = fuel_consumption
			
		end
		
		def time
			(distance.to_f / groundspeed * 120).round / 2.0
		end
		
		def zone_fuel
			(fuel_consumption / 6 * time).round / 10.0
		end
		
		def mean_temperature
			@mean_temperature ||= ((sqrt(ISA_SEA_LEVEL_TEMPERATURE) + sqrt(absolute_temperature)) / 2) ** 2
		end
		
		def absolute_temperature
			@absolute_temperature ||= oat + ZERO_CELCIUS
		end
		
		def static_pressure
			unless @static_pressure
				if altitude > ISA_TROPOSPHERE
					@static_pressure = 1282.03/10 ** (altitude / 47912.5808)
				else
					@static_pressure = ISA_SEA_LEVEL_PRESSURE / 10 ** (altitude / 220.82682 / mean_temperature)
				end
			end
			@static_pressure
		end

		def mach_no
			unless @mach_no
				pressure_coefficient = ISA_SEA_LEVEL_PRESSURE / static_pressure
				@mach_no = sqrt(5 * ( pressure_coefficient * ( ( (cas**2 / 2188648.141) + 1) ** 3.5) - pressure_coefficient + 1) ** (2.0/7) - 5)
			end
			@mach_no
		end
		
		def tas
			@tas ||= (ISA_SEA_LEVEL_SPEED_OF_SOUND * mach_no * sqrt( absolute_temperature / ISA_SEA_LEVEL_TEMPERATURE)).round
		end
		
		def wca
			@wca ||= (asin(sin((winddirection-track).radians)*windspeed.to_f/tas)).degrees.round
		end
	
		def heading
			unless @heading
				@heading = track + wca
				@heading = @heading + 360 if @heading < 0
			end
			@heading
		end
	
		def groundspeed
			@groundspeed ||= sqrt( tas**2 + windspeed**2 - (2*tas * windspeed * cos((winddirection-track-wca).radians))).round
		end
	
		def inspect
			"#{from} to #{to} @ #{altitude}ft, CAS #{cas}kt, OAT #{oat}C, TAS #{tas}kt, TRK #{"%03d" % track}, W/V #{"%03d" % winddirection}/#{windspeed}kt, HDG #{"%03d" % heading}, G/S #{groundspeed}kt, Dist #{distance}nm, Time #{time}m, Consumption #{fuel_consumption}/hr, Zone Fuel #{zone_fuel}"
		end
		
	end
	
	class MetSector
	
		attr_reader :from, :to
	
		def initialize( from, to )
			@from = from
			@to = to
			@forecasts = []
		end
		
		def add_forecast( forecast )
			@forecasts << forecast
		end
		
		def parse( string )
			string.each_line do |line|
				if match = /(\d+)\t(\d+)\t(\d+)\t(-?\d+)/.match(line)
					add_forecast Forecast.new( match[1].to_i, match[2].to_i, match[3].to_i, match[4].to_i )
				end
			end
		end
		
		def forecast( altitude, variation = nil )
		
			@forecasts.sort!

			altitude = altitude.to_i
			
			for fc in @forecasts
				if fc.altitude == altitude
					fc.variation = variation if variation
					return fc
				elsif fc.altitude < altitude
					low = fc
				elsif fc.altitude > altitude
					high = fc
					break
				end
			end
			
			raise "Forecast unavailable for #{altitude}" unless low and high

			multiplier = (altitude - low.altitude) / (high.altitude - low.altitude).to_f
			
			fc = Forecast.new(
				altitude,
				((high.winddirection - low.winddirection) * multiplier + low.winddirection).round,
				((high.windspeed - low.windspeed) * multiplier + low.windspeed).round,
				((high.temperature - low.temperature) * multiplier + low.temperature).round
			)
			
			fc.variation = variation if variation
			fc
	
		end
	
	end
	
	class Forecast
	
		attr_reader :altitude, :windspeed, :temperature
		attr_accessor :variation
	
		def initialize( altitude, winddirection, windspeed, temperature )
			@altitude = altitude
			@winddirection = winddirection # TODO: accept velocity
			@windspeed = windspeed
			@temperature = temperature
			@variation = 0
		end
		
		def <=>(other)
			altitude <=> other.altitude
		end
		
		def winddirection
			@winddirection + variation
		end
		
	end
	
	class FixedLeg < Leg
	
		attr_reader :fuel_consumption, :time, :zone_fuel
	
		def initialize(raw_fuel_consumption, raw_time = nil)
		
			@time = raw_time.to_f || nil

			if @time > 0

				@fuel_consumption = raw_fuel_consumption
				@zone_fuel = (raw_fuel_consumption / 6 * @time).round / 10.0

			else

				@fuel_consumption = nil
				@zone_fuel = raw_fuel_consumption
			
			end
			
		end
		
		[:alt, :cas, :oat, :tas, :track, :winddirection, :windspeed, :heading, :groundspeed, :distance].each do |m|
			define_method(m) { nil }
		end
		
	end
	
	class Departure < FixedLeg
		def from
			'Departure'
		end
		def to
			''
		end
	end

	class InstrumentApproach < FixedLeg
		def from
			'Instrument'
		end
		def to
			'Approach'
		end
	end

	class MissedApproach < FixedLeg
		def from
			'Missed'
		end
		def to
			'Approach'
		end
	end

	class Reserve < FixedLeg
		def from
			'Reserve'
		end
		def to
			''
		end
	end
	
	class Contingency < FixedLeg
	
		attr_reader :percentage

		def initialize(percentage, zone_fuel)
			@percentage = percentage
			@time = nil
			@fuel_consumption = nil
			@zone_fuel = zone_fuel
		end
		
		def from
			'Contingency'
		end
		def to
			"#{percentage}%"
		end
		
	end

end