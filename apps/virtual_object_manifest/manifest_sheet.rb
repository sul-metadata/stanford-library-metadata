require 'roo'
require 'roo-xls'

# Methods for processing and validating input file
class ManifestSheet

  attr_reader :sheet, :rows, :errors

  # Creates a new ManifestSheet
  # @param [File]  file    The input file object
  def initialize(file, logfile)
    @sheet = Roo::Spreadsheet.open(file, { csv_options: { encoding: 'bom|utf-8' } })
    @error_report = File.open(logfile, 'w')
  end

  def validate
    # Array to hold errors
    @errors = []
    # Check that all required headers are present
    headers = @sheet.row(1)
    validate_headers(headers)
    # Parse data columns based on headers
    @rows = @sheet.parse(sequence: 'sequence', root: 'root', druid: 'druid', clean: true)
    # Hash
    @root_sequence = {}
    validate_data
    check_sequence
    check_for_errors
    @sheet
  end

  def validate_headers(headers)
    # Checks that header contains sequence, root, and druid
    unless headers.include?('sequence') && headers.include?('root') && headers.include?('druid')
      @errors << 'File has incorrect headers: must include sequence, root, and druid'
      write_error_output
      exit
    end
  end

  def validate_data
    @rows.each_with_index do |row, i|
      next if row.compact.empty?
      # Checks druid pattern
      unless row[:druid] =~ /^druid:[a-z]{2}[0-9]{3}[a-z]{2}[0-9]{4}$/ || row[:druid] =~ /^[a-z]{2}[0-9]{3}[a-z]{2}[0-9]{4}$/
        @errors << "Druid not recognized: #{row[:druid]}"
      end
      # begin block to handle ArgumentError for integer test
      begin
        # Checks for empty cells
        if row.values.include?(nil)
          @errors << "Missing value in row #{i+2}"
        elsif @root_sequence.key?(row[:root].to_s)
          @root_sequence[row[:root].to_s] << Integer(row[:sequence])
        else
          @root_sequence[row[:root].to_s] = [Integer(row[:sequence])]
        end
        # Handles error if row[:sequence] cannot be converted to integer
      rescue ArgumentError
        @errors << "Sequence value cannot be converted to integer for #{row[:druid]}"
      end
    end
  end

  def check_sequence
    @root_sequence.each do |r, s|
      if s[0] != 0
        @errors << "Root #{r} missing parent numbered 0"
      else
        # Checks that sequence values are in numeric order
        while s.count >= 2
          if s.pop != s.last + 1
            @errors << "Root #{r} has disordered elements near #{s.last}"
          end
        end
      end
    end
  end

  def check_for_errors
    return if @errors.empty?
    write_error_output
    @sheet = nil
  end

  def write_error_output
    # Writes errors to file and exits
    CSV.open(@error_report, 'wb') do |csv|
      @errors.each { |e| csv << ["#{e}"] }
    end
  end

end
