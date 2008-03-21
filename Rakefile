def dms_to_degrees(hemisphere, degrees, minutes, seconds)
  hemisphere.strip!
  decimal = degrees.to_i + (minutes.to_i + seconds.to_i / 60.0) / 60
  if hemisphere == 'W' || hemisphere == 'S'
    0 - decimal
  elsif hemisphere == 'E' || hemisphere == 'N'
    decimal
  end
end

require 'rubygems'
require 'data_mapper'
require 'tmpdir'

DataMapper::Database.setup({
  :adapter => "sqlite3",
  :database => "flightplan.sqlite3",
})

require 'aerodrome'

desc "Generate aerodrome database"
task :generate_aerodromes do |t|
  Aerodrome.table.create!(true)

  pdf_url = "http://www.caa.govt.nz/airspace/AirNavReg/Aerodrome_co.pdf"
  pdf_file = File.join( Dir.tmpdir, 'aerodromes.pdf' )
  txt_file = File.join( Dir.tmpdir, 'aerodromes.txt' )

  match = /(.*)(\s+)([A-Z]{4,4}|    )(\s+)(Non-certificated|Charted only|Part 139 certificated|Not published)(\s*)(([N|S]) (\d+) (\d+) (\d+.\d)), (([E|W]) (\d+) (\d+) (\d+.\d))/

  `wget #{pdf_url} -O #{pdf_file}`
  `pdftotext -layout #{pdf_file} #{txt_file}`

  file = File.open(txt_file, 'r')
  for line in file
    if line =~ match
      Aerodrome.create({
        :name => $1.strip,
        :icao_code => $3.strip,
        :certification => $5.strip,
        :latitude => dms_to_degrees( $8, $9, $10, $11 ),
        :longitude => dms_to_degrees( $13, $14, $15, $16 )
      })
    end
  end

  `rm #{pdf_file}`
  `rm #{txt_file}`
end

desc "List aerodromes"
task :list_aerodromes do |t|
  Aerodrome.find(:all).each do |ad|
    puts ad.inspect
  end
end

desc "Calculate distance between two aerodromes"
task :distance_between do |t|
  from_code = ENV['FROM']
  to_code = ENV['TO']

  from = Aerodrome.first(:icao_code => from_code)
  to = Aerodrome.first(:icao_code => to_code)

  puts "#{from.icao_code} => #{to.icao_code}: #{from.distance_to(to)} nm"
end
