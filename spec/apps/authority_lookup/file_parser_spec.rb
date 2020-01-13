require '../apps/authority_lookup/file_parser'
require './spec_helper'

RSpec.describe FileParser do

  describe 'parses file' do
    it 'gets terms from file (file name)' do
      expect(FileParser.new(File.join(FIXTURES_DIR, 'authority_lookup/lookup_list.txt')).terms.size).to eq(2)
    end
    it 'gets terms from file (file object)' do
      lookup_list_file = File.open(File.join(FIXTURES_DIR, 'authority_lookup/lookup_list.txt'))
      expect(FileParser.new(lookup_list_file).terms.size).to eq(2)
    end
  end

end
