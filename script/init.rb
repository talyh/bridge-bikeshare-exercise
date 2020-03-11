require 'csv'
require 'pry'
require 'sequel'
require 'timeliness'

puts "*** Connecting to Database"
DB = Sequel.connect(ENV['DATABASE_URL'])

puts "*** Creating Tables"
DB.run <<-SQL
DROP TABLE IF EXISTS trips;
CREATE TABLE trips
(
  id INT NOT NULL PRIMARY KEY,
  start_time_str VARCHAR(100) NOT NULL,
  start_time TIMESTAMP,
  end_time_str VARCHAR(100) NOT NULL,
  end_time TIMESTAMP,
  duration_seconds INT NOT NULL,
  from_station_id INT,
  from_station_name VARCHAR(100),
  to_station_id INT,
  to_station_name VARCHAR(100),
  user_type VARCHAR(100) NOT NULL,
  original_filename VARCHAR(100) NOT NULL
);
SQL


trips = DB[:trips]

files = Dir["/data/**/*.csv"]

files.each do |file|
  puts "*** Processing #{file}"
  File.open(file) do |f|
    csv = CSV.read(f, headers: true)
    csv.each_slice(10000).each do |group|
      trips.multi_insert(
        group.map { |row|
         {
           id: row["trip_id"],
           start_time_str: row["trip_start_time"],
           end_time_str: row["trip_stop_time"],
           duration_seconds: row["trip_duration_seconds"],
           from_station_id: row["from_station_id"],
           from_station_name: row["from_station_name"],
           to_station_id: row["to_station_id"],
           to_station_name: row["to_station_name"],
           user_type: row["user_type"],
           original_filename: File.basename(file)
         }
       })
    end
  end
end
