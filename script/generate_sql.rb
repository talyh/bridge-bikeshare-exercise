#!/usr/bin/env ruby
# Takes a list of paths on the command line to CSV files and produces SQL INSERT statements for them
# ruby generate_sql.rb /path/to/csv /path/to/another csv


require 'csv'
require 'pry'
files = ARGV

# WARNING: GENERATING SQL LIKE THIS IN PRACTICE IS A BAD IDEA
# Exercize to the reader: why?
def bad_sanitize(str)
  str.gsub(/'/,"''")
end

def values(row, filename)
  "(#{row["trip_id"]}, '#{row["trip_start_time"]}', '#{row["trip_stop_time"]}', #{row["trip_duration_seconds"]}, #{row["from_station_id"]}, '#{bad_sanitize(row["from_station_name"])}', #{row["to_station_id"]}, '#{bad_sanitize(row["to_station_name"])}', '#{row["user_type"]}', '#{filename}')"
end

files.each do |file|
  filename = File.basename(file)
  File.open(file) do |f|
    csv = CSV.parse(f, headers: true)
    csv.each_slice(1000).each do |group|
      puts "INSERT INTO trips (id, start_time, end_time, duration, from_station_id, from_station_name, to_station_id, to_station_name, user_type, original_filename) VALUES"
      group[0..-1].each do |row|
        puts "#{values(row, filename)},"
      end
      puts "#{values(group[-1], filename)};"
    end
  end
  end
