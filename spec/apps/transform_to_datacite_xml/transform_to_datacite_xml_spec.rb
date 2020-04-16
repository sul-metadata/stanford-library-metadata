require '../apps/transform_to_datacite_xml/lib/modsulator'
require '../apps/transform_to_datacite_xml/app/models/modsulator_sheet'
require '../apps/transform_to_datacite_xml/app/models/normalizer'
require 'active_support/core_ext/hash'
require 'equivalent-xml'
require './spec_helper'

RSpec.describe Modsulator do

  before(:all) do
    @dc = Modsulator.new(File.open(File.join(FIXTURES_DIR, 'transform_to_datacite_xml/datacite_template_20200413_test.xlsx')), File.join(FIXTURES_DIR, './transform_to_datacite_xml/datacite_template_20200413_test.xlsx'))
  end


  describe 'transforms to Datacite XML:' do
    it 'uses the Datacite template file' do
      expect(@dc.template_xml).to eq(File.read('../apps/transform_to_datacite_xml/lib/modsulator/datacite_template.xml'))
    end
    it 'converts rows to expected XML (combined MODS/DataCite template)' do
      xml = @dc.convert_rows
      doc = Nokogiri::XML(xml)
      generated_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n#{doc.at_xpath('//*[local-name()="resource"]').to_s}"
      expected_xml = Nokogiri::XML(File.read(File.join(FIXTURES_DIR, 'transform_to_datacite_xml/datacite.xml'))).to_s
      expect(generated_xml).to be_equivalent_to(expected_xml)
    end
    it 'converts rows to expected XML (DataCite-only template)' do
      dc = Modsulator.new(File.open(File.join(FIXTURES_DIR, 'transform_to_datacite_xml/datacite_only_template_20200415_test.xlsx')), File.join(FIXTURES_DIR, './transform_to_datacite_xml/datacite_only_template_20200415_test.xlsx'))
      xml = dc.convert_rows
      doc = Nokogiri::XML(xml)
      generated_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n#{doc.at_xpath('//*[local-name()="resource"]').to_s}"
      expected_xml = Nokogiri::XML(File.read(File.join(FIXTURES_DIR, 'transform_to_datacite_xml/datacite.xml'))).to_s
      expect(generated_xml).to be_equivalent_to(expected_xml)
    end
  end

end
