require '../apps/authority_lookup/file_parser'

RSpec.describe FileParser do

  describe 'parses file' do
    it 'gets terms from file (file name)' do
      expect(FileParser.new('./fixtures/lookup_list.txt').terms.size).to eq(2)
    end
    it 'gets terms from file (file object)' do
      lookup_list_file = File.open('./fixtures/lookup_list.txt')
      expect(FileParser.new(lookup_list_file).terms.size).to eq(2)
    end
  end

end
