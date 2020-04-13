require '../apps/transform_to_datacite_xml/app/models/normalizer'
require './spec_helper'

# adapted from test in stanford-mods-normalizer

RSpec.describe Normalizer do

  before(:all) do
    @normalizer = Normalizer.new
  end

  describe 'exceptional?' do
    it 'returns false for a nil input' do
      expect(@normalizer.exceptional?(nil)).to be_falsey
    end

    it 'returns false for an element that does not have any attributes' do
      no_attributes_doc = Nokogiri::XML('<root_node><resourceType>randomtext</resourceType></root_node>')
      expect(@normalizer.exceptional?(no_attributes_doc.root.children[0])).to be_falsey
    end

    it 'returns true for an element that matches the condition' do
      exceptional_doc = Nokogiri::XML('<root_node><resourceType resourceTypeGeneral="yes">randomtext</resourceType></root_node>')
      expect(@normalizer.exceptional?(exceptional_doc.root.children[0])).to be_truthy
    end
  end

end
