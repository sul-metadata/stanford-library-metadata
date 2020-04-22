require './apps/transform_to_datacite_xml/app/models/modsulator_sheet'
require './apps/transform_to_datacite_xml/app/models/normalizer'
require 'sucker_punch'
require 'zip'
require 'nokogiri'

class DataCiteTransformerJob
  include SuckerPunch::Job
  def perform(file, filename, outfile)
    xml = Modsulator.new(file, filename).convert_rows
    doc = Nokogiri::XML(xml)
    records = doc.xpath('//*[local-name()="resource"]')
    xml_declaration = '<?xml version="1.0" encoding="UTF-8"?>'
    Zip::File.open(outfile, Zip::File::CREATE) do |z|
      records.each do |resource|
        druid = resource.parent['objectId']
        z.get_output_stream("#{druid}.xml") {|f| f.puts "#{xml_declaration}\n#{resource.to_s}"}
      end
    end
  end
end
