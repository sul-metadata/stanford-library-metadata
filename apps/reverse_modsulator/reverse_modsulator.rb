require 'nokogiri'
require 'csv'
require 'zip'
require_relative 'mods_file'

class ReverseModsulator

  attr_reader :dir, :filename, :template_xml, :namespace, :logfile, :analysis_only, :data

  # @param [String] source                     Input directory or file containing MODS records.
  # @param [String] filename                   The filename for the output CSV.
  # @param [Hash]   options
  # @option options [String]  :input
  # @option options [String]  :template_file   The path to the desired template file (a spreadsheet).
  # @option options [String]  :namespace       The namespace prefix used in the input files.
  # @option options [String]  :logfile         The path to the file for logging any data loss.
  # @option options [Boolean] :analysis_only   True: run data analysis only, do not convert data.
  def initialize(source, filename, options = {})
    @source = source
    @filename = filename
    @data = {}
    @data_loss = []

    if options[:input] == 'file' || @source.class == String && @source.end_with?('.xml')
      @process = 'file'
    elsif options[:input] == 'zip' || @source.class == String && @source.end_with?('.zip')
      @process = 'zip'
    elsif options[:input] == 'zip-stream'
      @process = 'zip-stream'
    elsif options[:input] == 'directory' || Dir.exist?(@source)
      @process = 'directory'
    else
      abort("Input type not recognized. Input must be a compiled MODS file, a ZIP file, or a directory.")
    end
    if options[:template_file]
      @template_filename = options[:template_file]
    else
      @template_filename = './apps/reverse_modsulator/modsulator_template.xml'
    end
    if options[:namespace]
      @namespace = options[:namespace]
    else
      @namespace = 'xmlns'
    end
    if options[:logfile]
      @logfile = options[:logfile]
    else
      @logfile = './public/reverse_modsulator/log.csv'
    end
    if options[:analysis_only] == true
      @analysis_only = true
    else
      @analysis_only = false
    end

    @template_xml = Nokogiri::XML(modify_template)
    get_template_elements_and_attributes

    if @process == 'directory'
      process_directory
    elsif @process == 'file'
      process_compiled_file
    elsif @process == 'zip'
      process_zip_file
    elsif @process == 'zip-stream'
      process_zip_stream
    end

  end

  # Replace subject subelements given as header codes with 'topic' for parseable XML.
  # @return [StringIO]          Modified template.
  def modify_template
    template = File.read(@template_filename)
    working_template = template.gsub(/\[\[s[un]\d+:p\d:type\]\]/, 'topic')
    StringIO.new(string=working_template, 'r')
  end

  # Process a directory of single-record MODS files where the filename is the druid.
  # Compare each MODS file to the template for possible data loss. Unless @analysis_only
  # is set to true, convert MODS record to replayable spreadsheet and write output
  # to specified file.
  def process_directory
    Dir.foreach(@source) do |f|
      next unless f.match(/[a-z]{2}[0-9]{3}[a-z]{2}[0-9]{4}\.xml/)
      druid = get_druid_from_filename(f)
      mods_file = MODSFile.new(Nokogiri::XML(File.open(File.join(@source, f))), @template_xml, @namespace)
      process_mods_file(mods_file, druid)
    end
    write_output if @analysis_only == false
    report_data_loss
  end

  # Process a compiled file of MODS records using the xmlDocs/xmlDoc structure.
  # Compare each MODS record to the template for possible data loss. Unless @analysis_only
  # is set to true, convert MODS record to replayable spreadsheet and write output
  # to specified file.
  def process_compiled_file
    doc = Nokogiri::XML(File.open(@source))
    records = doc.xpath('//*[local-name()="mods"]')
    records.each do |record|
      #  record
      druid = record.parent['objectId']
      doc_node = Nokogiri::XML(record.to_s)
      mods_file = MODSFile.new(doc_node, @template_xml, @namespace)
      process_mods_file(mods_file, druid)
    end
    write_output if @analysis_only == false
    report_data_loss
  end

  def process_zip_file
    Zip::File.open(@source) do |zip_file|
      zip_file.each do |entry|
        next if entry.directory?
        process_zip_entry(entry)
      end
      write_output if @analysis_only == false
    end
    report_data_loss
  end

  def process_zip_stream
    Zip::File.open_buffer(@source) do |zip_stream|
      zip_stream.each do |entry|
        next if entry.directory?
        process_zip_entry(entry)
      end
      write_output if @analysis_only == false
    end
    report_data_loss
  end

  def process_zip_entry(entry)
    druid = get_druid_from_filename(entry.name)
    return unless druid_is_valid?(druid)
    content = entry.get_input_stream
    mods_file = MODSFile.new(Nokogiri::XML(content), @template_xml, @namespace)
    process_mods_file(mods_file, druid)
  end

  # Transform MODS file to replayable spreadsheet.
  # @param [MODSFile] mods_file        MODSFile object for a MODS record.
  # @param [String]   druid            Druid associated with the MODS record.
  def process_mods_file(mods_file, druid)
    compare_mods_to_template(mods_file, druid)
    @data[druid] = mods_file.transform_mods_file if @analysis_only == false
  end

  # Get the druid for output from the MODS filename.
  # @param [String] mods_filename   Name of MODS input file.
  def get_druid_from_filename(mods_filename)
    f = File.basename(mods_filename, '.xml')
    f.gsub(/druid[:_]/, '')
  end

  def druid_is_valid?(druid)
    if druid.match?(/^[a-z][a-z][0-9][0-9][0-9][a-z][a-z][0-9][0-9][0-9][0-9]$/)
      return true
    else
      return false
    end
  end


  # Write CSV data output to file.
  # @param [Hash]   data        Processed data output.
  # @param [File]   outfile     File object for output rows.
  def write_output
    rows = data_to_rows
    CSV.open(@filename, 'wb') do |csv|
      rows.each {|row| csv << row}
    end
  end

  # Convert processed data hash to array of arrays with header codes as first entry.
  # Merge druid keys into data.
  # @return [Array]             Array of row arrays for output.
  def data_to_rows
    rows = []
    headers = get_ordered_headers
    rows << headers
    @data.each do |druid, column_hash|
      row_out = [druid]
      headers.each do |header|
        if header == 'druid'
          next
        elsif column_hash.keys.include?(header)
          row_out << column_hash[header].gsub(/\n/, " ").squeeze(" ")
        else
          # Padding if row does not have data for that header
          row_out << ""
        end
      end
      rows << row_out
    end
    rows
  end

  # Put data header codes in the order in which they appear in the template.
  # @return [Array]             Ordered list of header codes appearing in the data output.
  def get_ordered_headers
    headers = get_headers
    template_headers = get_template_headers
    ordered_headers = ['druid', 'sourceId']
    # Select only headers with values somewhere in the data
    template_headers.each {|th| ordered_headers << th if headers.include?(th)}
    ordered_headers
  end

  # Get array of header codes from processed data.
  # @return [Array]             Unordered list of header codes appearing in the data output.
  def get_headers
    headers = []
    @data.each do |druid, column_hash|
      headers << column_hash.keys
    end
    headers_out = headers.flatten.uniq
  end

  # Get ordered array of header codes from the template.
  # @return [Array]             Ordered list of header codes appearing in the template.
  def get_template_headers
    template_headers = File.read(@template_filename).scan(/\[\[([A-Za-z0-9:]+)\]\]/).uniq.flatten
  end

  # Count the number of instances of each element and attribute path in a MODS record.
  # @param [Nokogiri::XML] document    Nokogiri XML object to process.
  # @return [Hash] elements            Key: element path present in document; value: number of instances of that path.
  # @return [Hash] attributes          Key: attribute path present in document; value: number of instances of that path.
  def get_element_and_attribute_counts(document)
    elements = {}
    attributes = {}
    document.elements.each do |element|
      element.traverse do |n|
        next unless n.element?
        path = n.ancestors.map {|x| x.name}.reverse.push(n.name).drop(1).join("/")
        if elements.keys.include?(path)
          elements[path] += 1
        else
          elements[path] = 1
        end
        n.keys.each do |k|
          if attributes.keys.include?("#{path}[@#{k}]")
            attributes["#{path}[@#{k}]"] += 1
          else
            attributes["#{path}[@#{k}]"] = 1
          end
        end
      end
    end
    return elements, attributes
  end

  # Count the number of instances of each element and attribute path in the template.
  def get_template_elements_and_attributes
    @template_elements, @template_attributes = get_element_and_attribute_counts(@template_xml)
  end

  # Compare the path inventory in the MODS record and the template to report cases where
  # a path has more instances in the record than the template, or a path in the record is
  # not present in the template at all.
  # @param [MODSFile] mods_file     The MODSFile object for the record being processed.
  # @param [String]   druid         The druid associated with the MODS record being processed.
  def compare_mods_to_template(mods_file, druid)
    mods_elements, mods_attributes = get_element_and_attribute_counts(mods_file.mods)
    mods_elements.keys.each do |e|
      next if ["mods/subject/genre", "mods/subject/geographic", "mods/subject/topic"].include?(e)
      @data_loss << compare_path_counts(mods_elements, @template_elements, e, druid)
    end
    mods_attributes.keys.each do |a|
      @data_loss << compare_path_counts(mods_attributes, @template_attributes, a, druid)
    end
  end

  # Compare a single path  in the MODS record and the template and report when it has more
  # instances in the record than the template, or is not present in the template at all.
  # @param [Hash]   mods            Key: path in MODS record; value: number of occurrences of path.
  # @param [Hash]   template        Key: path in template; value: number of occurrences of path.
  # @param [String] path            The particular path being processed.
  # @param [String] druid           The druid associated with the MODS record being processed.
  def compare_path_counts(mods, template, path, druid)
    if template.keys.include?(path) && mods[path] > template[path]
      return [druid, "Dropped #{mods[path] - template[path]} instance(s) of #{path}"]
    elsif !template.keys.include?(path)
      return [druid, "Dropped all #{mods[path]} instance(s) of #{path}"]
    else
      return nil
    end
  end

  # Write results of data loss analysis to log file.
  # @param [Array] log              Messages to write to log.
  def report_data_loss
    if @data_loss.compact.size > 0
      CSV.open(@logfile, 'wb') do |csv|
        csv << ["Druid", "Description"]
        @data_loss.compact.each do |l|
          csv << l
        end
      end
    end
  end

end
