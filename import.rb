#!/usr/bin/env ruby

require "fileutils"
require "date"
require "sequel"
require "csv"
require "json"

unless Object.const_defined?("DB")
  DB = Sequel.connect("postgres://localhost/dwolla")
end

module Dwolla
  class CsvImport
    attr_accessor :dir, :files, :filename, :to_be_processed, :processed, :raw_data, :transactions, :account_header, :header, :processed_path, :json_dir
    def initialize(args = {})
      @dir = args[:dir] || ARGV[0] || File.join(Dir.pwd, "csv")
      @json_dir = args[:json_dir] || ARGV[1] || File.join(Dir.pwd, "json")
      @processed_dir = args[:processed_dir] || File.join(@dir,"processed")
      unless @dir.nil?
        @files = get_files
      else
        @raw_data = args[:raw_data]
      end
    end

    def import_data
      @transactions.each do |tranx|
        unless dupe?(tranx)
          new_record = DB[:dwolla_transactions] << tranx
          puts Time.now.to_s + ": Imported transaction #{tranx[:id]} as #{new_record.inspect}."
        end
      end
    end

    def dupe?(row) # {{{ Verify row has unique fee_id and txid
      DB[:dwolla_transactions].filter(:fee_id => row[:fee_id], :txid => row[:txid]).count > 0
    end # }}}

    def parse_files
      parse_data until @files.size == 0
    end

    def parse_data # {{{ Make @transactions from @raw_data
      if @raw_data.nil?
        file = @files.shift
        puts Time.now.to_s + ": Parsing #{file}"
        @raw_data = CSV.read(file)
      end
      @account_header = @raw_data.shift
      @raw_data.shift # Empty line
      @header = @raw_data.shift
      if confirm_header
        puts Time.now.to_s + ": File has #{@raw_data.size} rows after header stripping."
        @transactions = @raw_data.inject([]) { |a,b| a << set_tranx_columns(b) }
      else
        raise "File #{file} didn't have a good header, check for format change and/or valid file!!"
      end
      clean_file(file)
    end # }}}

    def clean_file(file) # {{{ Move specified file to the processed dir, so we don't have to process it again
      puts Time.now.to_s + ": Moving #{file} to #{@processed_dir}"
      FileUtils.mkpath(@processed_dir) unless File.exists?(@processed_dir)
      FileUtils.mv(file, @processed_dir)
    end # }}}
   
    def confirm_header # {{{ Help us catch format changes
      @header.join(",") == "Type,Date,Gross,Fee,Fee ID,Amount,ID,Source,Source ID,Destination,Destination ID,Comments"
    end # }}}

    def export_data # {{{ Take all unexported transactions, and export into a big JSON file.
      ready_to_export = DB[:dwolla_transactions].filter(:exported => false).all
      puts Time.now.to_s + ": Found #{ready_to_export.size} transactions to export."
      export_file = File.join(@json_dir, "dwolla_transactions_#{Time.now.to_i}.json")
      exportable = ready_to_export.map { |tranx| tranx.delete(:id); tranx.delete(:exported); tranx }
      DB.transaction do
        FileUtils.mkpath(@json_dir) unless File.exists?(@json_dir)
        File.open(export_file,"w") do |json_file|
          json_file.puts exportable.to_json
        end
        ready_to_export.each { |tranx| DB[:dwolla_transactions].filter(:id => tranx[:id]).update(:exported => true) }
      end
    end # }}}

    def get_files
      @files = Dir.glob(@dir + "/*.csv")
    end

    def set_tranx_columns(row) # {{{ Turn a raw row into a transaction record
      if row.size == 12
        tranx = {
          :type => row[0],
          :date => DateTime.parse(row[1]),
          :gross => row[2],
          :fee => row[3],
          :fee_id => row[4],
          :amount => row[5],
          :txid => row[6],
          :source_account => row[7],
          :source_id => row[8],
          :destination_account => row[9],
          :destination_id => row[10],
          :comment => row[11]
        }
      else
        raise "Row doesn't have 11 columns, probably not transaction data!!"
      end
    end # }}}
  end
end

if $0 == __FILE__
  dir = ARGV[0]
  json_dir = ARGV[1]
  if dir.nil?
    dir = File.join(Dir.pwd, "csv")
    json_dir = File.join(Dir.pwd, "json")
  end
  parser = Dwolla::CsvImport.new(:dir => dir, :json_dir => json_dir)
  puts Time.now.to_s + ": Dwolla CSV Parser starting with #{parser.files.size} files to parse."
  exit 0 if parser.files.size == 0
  parser.parse_files
  parser.import_data
  parser.export_data
end
