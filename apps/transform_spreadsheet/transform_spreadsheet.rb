require 'roo'
require 'csv'

class Transformer

  attr_reader :map_data, :string_data, :complex_data, :data_rules, :output_order, :exit

  def initialize(in_filename, map_filename, out_filename)
    @in_filename = in_filename
    @map_filename = map_filename
    @out_filename = out_filename

    ## Hashes for data from mapfile
    # Fields to map directly from source
    @map_data = {}
    # Fields to populate with string (no {variables})
    @string_data = {}
    # Fields to populate with string containing {variables}
    @complex_data = {}
    # Fields with dependencies on other fields
    @data_rules = {}

    # Order of target fields in mapfile, to use for output
    @output_order = []

    @exit = false
  end

  def transform
    process_mapfile(@map_filename)
    process_data(@in_filename, @out_filename)
  end

  def open_spreadsheet(filename)
    spreadsheet = case File.extname(filename)
    when '.csv' then Roo::Spreadsheet.open(filename, extension: :csv)
    when '.xls' then Roo::Spreadsheet.open(filename, extension: :xls)
    when '.xlsx' then Roo::Spreadsheet.open(filename, extension: :xlsx)
    else @exit = true
    end
    return spreadsheet
  end

  def process_mapfile(filename)
    mapping = open_spreadsheet(filename)

    mapping.each do |fields|
      # Convert all values to strings
      fields.map! {|x| x.to_s}
      # Add target field to output order
      @output_order << fields[0]
      # Skip the rest if target field is only value in row (will be blank column under header in output)
      next if fields.size == 1
      # Populate mapping hashes based on value in third column
      @map_data[fields[0]] = fields[1] if fields[2] == "map"
      @string_data[fields[0]] = fields[1] if fields[2] == "string"
      @complex_data[fields[0]] = fields[1] if fields[2] == "complex"
      # Check for fourth column value and add dependency rule if present
      @data_rules[fields[0]] = fields[3] if fields.size == 4 && fields[3] != nil && fields[3] != ""
    end
  end

  def process_data(in_filename, out_filename)
    spreadsheet = open_spreadsheet(in_filename)

    # Open output file
    outfile = CSV.open(out_filename, 'wb')
    # Write target headers to output
    outfile << @output_order

    # Get source headers for data field indexes
    data_fields = spreadsheet.row(1)
    # Iterate through rows in sheet
    spreadsheet.each do |row|
      # Skip header row
      next if row == data_fields
      # Convert all values to strings
      row.map! {|x| x.to_s}
      # Populate row hash with constant string data from mapfile
      data_out = Hash.new.merge(@string_data)
      # Add source data to row hash based on simple mapping
      @map_data.each do |target, source|
        data_out[target] = row[data_fields.index(source)] if data_fields.include?(source)
      end
      # Add source data to row hash incorporating {variables}
      @complex_data.each do |target, source|
        # Generate data only if all variable names are also present in data field names
        data_out[target] = source.gsub(/{[^}]*}/) {|s| row[data_fields.index(s[1..-2])]} if source.scan(/{([^}]*)}/).flatten - data_fields == []
      end
      # Delete data from row hash when required dependency is not present
      @data_rules.each do |target, rule|
        if data_fields.index(rule) == nil || row[data_fields.index(rule)] == nil || row[data_fields.index(rule)] =~ /^\s*$/
          data_out[target] = nil
        end
      end
      outfile << output_row_data(data_out)
    end
    outfile.close
  end

  def output_row_data(row)
    # Ordered array for output data
    row_out = []
    ## Write data to output
    @output_order.each do |field|
      if row[field] != nil
        # Remove newlines and extra spaces from within cell values
        data = row[field].gsub(/[\r\n]/," ").gsub(/\s+/," ").strip
        # Add cleaned data to output array
        row_out << data
      else
        # Padding for blank column if data not present
        row_out << ""
      end
    end
    return row_out
  end

end
