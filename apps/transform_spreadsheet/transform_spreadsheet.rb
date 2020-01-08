require 'roo'
require 'csv'

class Transformer

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
  end

  def transform
    process_mapfile
    process_data
  end

  def fail_error(msg)
    puts "FAIL: #{msg}"
    exit
  end

  def process_mapfile
    mapping = case File.extname(@map_filename)
    when '.csv' then Roo::Spreadsheet.open(@map_filename, extension: :csv)
    when '.xls' then Roo::Spreadsheet.open(@map_filename, extension: :xls)
    when '.xlsx' then Roo::Spreadsheet.open(@map_filename, extension: :xlsx)
    else fail_error("Invalid input file extension: use .csv, .xls, or .xlsx")
    end

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

  def process_data
    spreadsheet = case File.extname(@in_filename)
    when '.csv' then Roo::Spreadsheet.open(@in_filename, extension: :csv)
    when '.xls' then Roo::Spreadsheet.open(@in_filename, extension: :xls)
    when '.xlsx' then Roo::Spreadsheet.open(@in_filename, extension: :xlsx)
    else fail_error("Invalid input file extension: use .csv, .xls, or .xlsx")
    end

    # Open output file
    @outfile = CSV.open(@out_filename, 'wb')
    # Write target headers to output
    @outfile << @output_order

    # Get source headers for data field indexes
    data_fields = spreadsheet.row(1)
    # Iterate through rows in sheet
    spreadsheet.each do |row|
      # Skip header row
      next if row == data_fields
      # Convert all values to strings
      row.map! {|x| x.to_s}
      # Populate row hash with constant string data from mapfile
      @data_out = Hash.new.merge(@string_data)
      # Add source data to row hash based on simple mapping
      @map_data.each do |target, source|
        @data_out[target] = row[data_fields.index(source)] if data_fields.include?(source)
      end
      # Add source data to row hash incorporating {variables}
      @complex_data.each do |target, source|
        # Generate data only if all variable names are also present in data field names
        @data_out[target] = source.gsub(/{[^}]*}/) {|s| row[data_fields.index(s[1..-2])]} if source.scan(/{([^}]*)}/).flatten - data_fields == []
      end
      # Delete data from row hash when required dependency is not present
      @data_rules.each do |target, rule|
        if data_fields.index(rule) == nil || row[data_fields.index(rule)] == nil || row[data_fields.index(rule)] =~ /^\s*$/
          @data_out[target] = nil
        end
      end
      output_row_data
    end
    @outfile.close
  end

  def output_row_data
    # Ordered array for output data
    row_out = []
    ## Write data to output
    @output_order.each do |field|
      if @data_out[field] != nil
        # Remove newlines and extra spaces from within cell values
        data = @data_out[field].gsub(/[\r\n]/," ").gsub(/\s+/," ").strip
        # Add cleaned data to output array
        row_out << data
      else
        # Padding for blank column if data not present
        row_out << ""
      end
    end
    # Write row to output
    @outfile << row_out
  end

end
