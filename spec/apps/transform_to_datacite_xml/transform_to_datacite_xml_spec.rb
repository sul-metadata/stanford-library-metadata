require '../apps/transform_to_datacite_xml/lib/modsulator'
require '../apps/transform_to_datacite_xml/app/models/modsulator_sheet'
require '../apps/transform_to_datacite_xml/app/models/normalizer'
require 'active_support/core_ext/hash'
require 'equivalent-xml'
require './spec_helper'

RSpec.describe Modsulator do

  before(:all) do
    @dc = Modsulator.new(File.open('./fixtures/datacite_template_20200110_test.xlsx'), './fixtures/datacite_template_20200110_test.xlsx')
  end


  describe 'transforms to Datacite XML:' do
    it 'uses the Datacite template file' do
      expect(@dc.template_xml).to eq(File.read('../apps/transform_to_datacite_xml/lib/modsulator/datacite_template.xml'))
    end
    it 'converts rows to expected XML' do
      xml = @dc.convert_rows
      generated_xml = Nokogiri::XML(xml)
      expected_xml = Nokogiri::XML(File.read('./fixtures/datacite.xml'))
      expect(generated_xml).to be_equivalent_to(expected_xml).ignoring_attr_values('datetime')
    end
  end

end
