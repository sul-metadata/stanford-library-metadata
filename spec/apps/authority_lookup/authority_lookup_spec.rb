require '../apps/authority_lookup/authority_lookup'
require '../apps/authority_lookup/file_parser'

RSpec.describe AuthorityLookup do

  describe 'looks up terms' do
    it 'returns results for each term' do
      term_list = FileParser.new('./fixtures/lookup_list.txt').terms
      results = AuthorityLookup.new(term_list, 'LOCNAMES_LD4L_CACHE', 'https://lookup.ld4l.org/authorities/search/linked_data/', 'outfile').result_set
      expect(result_set.size).to eq(2)
    end
  end
end
