# this example requires DBI
# DBI is not included with a standard Mac OS X ruby installation
# get MacPorts from http://www.macports.org/
# (or compile from source)
# sudo port install rb-dbi
# sudo gem install active_support

require 'flight_plan'
require 'rubygems'
require 'active_support'
require 'DBI'

include FlightPlan

fp = IFRFlightPlan.new( :lbs, '00:00' )

npch = MetSector.new( 'NP', 'CH')
npch.parse('3000	180	20	4
5000	210	20	0
7000	220	20	-4
10000	230	30	-10
14000	250	40	-16
18000	260	50	-24
22000	260	60	-28')

chnv = MetSector.new( 'CH', 'NV')
chnv.parse('3000	200	35	2
5000	220	45	-2
7000	220	45	-6
10000	220	40	-11
14000	210	39	-18
18000	200	45	-26
22000	210	45	-30')


#                   from     to       alt    met   var  cas  trk  dst  fuel
fp.add_leg Departure.new(120, 0.0)
fp.add_leg Leg.new('NP', 'TOC', 15000, npch, -21, 135, 177, 15, 1250) # 144
fp.add_leg Leg.new('TOC', 'NS', 18000, npch, -21, 160, 177, 129, 980) # 144
fp.add_leg Leg.new('NS', 'BIRIN', 18000, npch, -22, 160, 171, 20, 980) # 136
fp.add_leg Leg.new('BIRIN', 'SANDY', 18000, npch, -22, 160, 171, 44, 980) # 136
fp.add_leg Leg.new('SANDY', 'MUPAN', 18000, npch, -23, 160, 171, 32, 980) # 136
fp.add_leg Leg.new('MUPAN', 'CH', 18000, npch, -23, 160, 171, 40, 980) # 136
fp.add_leg Leg.new('CH', 'IDARA', 18000, chnv, -24, 160, 191, 40, 980) # 105
fp.add_leg Leg.new('IDARA', 'OU', 18000, chnv, -24, 160, 191, 65, 980) # 105
fp.add_leg Leg.new('OU', 'MIPAK', 18000, chnv, -24, 160, 184, 23, 980) # 58
fp.add_leg Leg.new('MIPAK', 'TOD', 18000, chnv, -25, 160, 184, 8, 980) # 58
fp.add_leg Leg.new('TOD', 'SW', 11000, chnv, -25, 180, 184, 27, 800) # 58
fp.add_leg InstrumentApproach.new(200)
fp.add_leg MissedApproach.new(137)
fp.add_leg Leg.new('BE', 'BIMAX', 4000, chnv, -25, 160, 226, 33, 980)
fp.add_leg Leg.new('BIMAX', 'NV', 4000, chnv, -25, 160, 227, 40, 980)
fp.add_leg InstrumentApproach.new(200)
fp.add_leg Reserve.new(850, 45)
fp.contingency( 10 ) # of all but reserve

DBI::Utils::TableFormatter.ascii(
	['From', 'To', 'Alt', 'CAS', 'OAT', 'TAS', 'Trk', 'Wind', 'Hdg', 'G/S', 'Dist', 'Time', 'ETA', 'Cons', 'Zone', 'Total'],
	fp.columns
)
