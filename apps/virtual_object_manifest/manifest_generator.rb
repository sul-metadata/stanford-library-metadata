require 'csv'
require 'roo'
require_relative 'manifest_sheet'

# Generates virtual object manifest based on validated spreadsheet input
class ManifestGenerator

  attr_reader :infile, :sheet, :current_parent, :data

  # Creates a new ManifestGenerator
  # @param [String]  filename    The filename of the input spreadsheet.
  def initialize(in_filename, out_filename, log_filename, stats_filename)
    @in_filename = in_filename
    @out_filename = out_filename
    @log_filename = log_filename
    @stats_filename = stats_filename
  end

  def generate_manifest
    # Create new ManifestSheet object (using Roo) from input file
    @infile = ManifestSheet.new(@in_filename, @log_filename)
    # Validate incoming data and return validated spreadsheet object
    @sheet = @infile.validate
    return 0 if @sheet == nil
    data = process_sheet(@sheet)
    report_output_stats(data)
    write_output_file(data)
  end

  def process_sheet(sheet)
    # Hash to store output data for manifest
    @data = {}
    # Populate output data hash:
    # key = parent druid (sequence = 0),
    # value = array of child druids (sequence = 1-N)
    # Assumes that incoming data has passed validation
    sheet.each(sequence: 'sequence', druid: 'druid') do |row|
      next if row[:druid] == 'druid'
      process_row(row)
    end
    @data
  end

  def process_row(row)
    druid = row[:druid]
    # Set parent druid if sequence = 0
    if row[:sequence] == 0 || row[:sequence] == '0'
      @current_parent = druid
      # If child belongs to new parent, add parent key to hash and initialize value array with first child
      @data[@current_parent] = [druid]
    else
      # If child belongs to existing parent, add to value array
      @data[@current_parent] << druid
    end
  end

  def report_output_stats(data)
    # Reports number of child objects assigned to each parent in the manifest
    CSV.open(@stats_filename, 'wb') do |csv|
      csv << ["Parent druid", "Child object count"]
      data.each { |parent, children| csv << ["#{parent}", "#{children.count}"] }
    end
  end

  def write_output_file(data)
    # Write data to manifest CSV file
    # First column contains parent druid
    # Subsequent columns contain child druids in sequence order
    CSV.open(@out_filename, 'wb') do |csv|
      data.each_value { |druids| csv << druids }
    end
  end
end
