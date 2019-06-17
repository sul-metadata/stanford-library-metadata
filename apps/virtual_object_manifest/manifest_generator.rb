require 'csv'
require 'roo'
require_relative 'manifest_sheet'

# Generates virtual object manifest based on validated spreadsheet input
class ManifestGenerator

  # Creates a new ManifestGenerator
  # @param [String]  filename    The filename of the input spreadsheet.
  def initialize(infile)
    @infile = infile
    @outfile = './public/virtual_object_manifest/manifest.csv'
    @statfile = './public/virtual_object_manifest/stats.csv'
  end

  def generate_manifest
    # Create new ManifestSheet object (using Roo) from input file
    infile = ManifestSheet.new(@infile)
    # Validate incoming data and return validated spreadsheet object
    sheet = infile.validate
    return unless File.zero?("./public/virtual_object_manifest/errors.csv")
    data = generate_data_hash(sheet)
    report_output_stats(data)
    write_output_file(data)
  end

  def generate_data_hash(sheet)
    # Hash to store output data for manifest
    @data = {}
    # Populate output data hash:
    # key = parent druid (sequence = 0),
    # value = array of child druids (sequence = 1-N)
    # Assumes that incoming data has passed validation
    sheet.each(sequence: 'sequence', druid: 'druid') do |row|
      next if row[:druid] == 'druid'
      populate_data_hash(row)
    end
    @data
  end

  def populate_data_hash(row)
    # Add druid prefix if not present
    druid = check_druid_prefix(row[:druid])
    # Set parent druid if sequence = 0
    if row[:sequence] == 0 || row[:sequence] == '0'
      @current_parent = row[:druid]
      # If child belongs to new parent, add parent key to hash and initialize value array with first child
      @data[@current_parent] = [druid]
    else
      # If child belongs to existing parent, add to value array
      @data[@current_parent] << druid
    end
  end

  def check_druid_prefix(druid)
    # Add prefix if not already present
    if druid =~ /^[a-z]{2}[0-9]{3}[a-z]{2}[0-9]{4}$/
      "druid:#{druid}"
    else
    # Return value
      druid
    end
  end

  def report_output_stats(data)
    # Reports number of child objects assigned to each parent in the manifest
    CSV.open(@statfile, 'wb') do |csv|
      csv << ["Parent druid", "Child object count"]
      data.each { |parent, children| csv << ["#{parent}", "#{children.count}"] }
    end
  end

  def write_output_file(data)
    # Write data to manifest CSV file
    # First column contains parent druid
    # Subsequent columns contain child druids in sequence order
    CSV.open(@outfile, 'wb') do |csv|
      data.each_value { |druids| csv << druids }
    end
  end
end
