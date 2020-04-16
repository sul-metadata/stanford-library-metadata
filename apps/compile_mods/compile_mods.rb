require 'rubygems'
require 'nokogiri'
require 'zip'

class MODSCompiler

  def initialize(source, filename, outfile)
    @source = source
    @filename = filename
    @outfile = File.open(outfile, 'w')
  end

  def process_input
    time = Time.now.strftime('%Y-%m-%d %I:%M:%S%p')
    @outfile.write("<xmlDocs xmlns=\"http://library.stanford.edu/xmlDocs\" datetime=\"#{time}\" sourceFile=\"#{@filename}\">\n")
    process_zip_stream
    @outfile.write("</xmlDocs>")
    @outfile.close
  end

  def process_zip_stream
    Zip::File.open_buffer(@source) do |zip_stream|
      zip_stream.each do |entry|
        next if entry.directory?
        process_zip_entry(entry)
      end
    end
  end

  def process_zip_entry(entry)
    druid = get_druid_from_filename(entry.name)
    return unless druid_is_valid?(druid)
    content = entry.get_input_stream
    process_content(content, druid)
  end

  def process_content(content, druid)
    doc = Nokogiri::XML(content)
    record = doc.root
    @outfile.write("<xmlDoc id=\"descMetadata\" objectId=\"#{druid}\">\n" + record.to_xml + "\n</xmlDoc>\n")
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

end
