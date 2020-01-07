require '../apps/authority_lookup/term_lookup'

RSpec.describe TermLookup do

  before(:all) do
    @term_lookup_test = TermLookup.new('Dorothy Dunnett', 'LOCNAMES_LD4L_CACHE', 'https://lookup.ld4l.org/authorities/search/linked_data/', nil, 10, 'en')
  end

  describe 'exits if arguments missing' do
    it 'exits if search term not provided' do
      expect(TermLookup.new(nil, 'authority', 'base url', nil, nil, nil).exit).to eq(true)
    end
    it 'exits if authority not provided' do
      expect(TermLookup.new('term', '', 'base url', nil, nil, nil).exit).to eq(true)
    end
    it 'exits if base URL not provided' do
      expect(TermLookup.new('', 'authority', 'base url', nil, nil, nil).exit).to eq(true)
    end
  end

  describe 'parses optional arguments' do
    it 'sets subauthority' do
      subauthority_option = TermLookup.new('term', 'authority', 'http://example.com/', 'naf', nil, nil)
      expect(subauthority_option.subauthority).to eq('naf')
    end
    it 'sets limit' do
      limit_option = TermLookup.new('term', 'authority', 'base url', nil, 1, nil)
      expect(limit_option.limit).to eq(1)
    end
    it 'sets language' do
      language_option = TermLookup.new('term', 'authority', 'base url', nil, nil, 'ru')
      expect(language_option.language).to eq('ru')
    end
  end

  describe 'prepares query' do
    it 'encodes the search term' do
      expect(@term_lookup_test.encode_search_term('Dorothy Dunnett')).to eq('Dorothy+Dunnett')
    end
    it 'constructs a basic query' do
      expect(@term_lookup_test.construct_query('Dorothy+Dunnett')).to eq('https://lookup.ld4l.org/authorities/search/linked_data/LOCNAMES_LD4L_CACHE?q=Dorothy+Dunnett&maxRecords=10&lang=en')
    end
    it 'constructs a query with options' do
      options_test = TermLookup.new('Dorothy Dunnett', 'LOCNAMES_LD4L_CACHE', 'https://lookup.ld4l.org/authorities/search/linked_data/', 'naf', 1, 'ru')
      expect(options_test.construct_query('Dorothy+Dunnett')).to eq('https://lookup.ld4l.org/authorities/search/linked_data/LOCNAMES_LD4L_CACHE/naf?q=Dorothy+Dunnett&maxRecords=1&lang=ru')
    end
  end

  describe 'performs query' do
    it 'returns a result' do
      lookup_result = @term_lookup_test.lookup_term('Dorothy Dunnett')
      expect(lookup_result['Dorothy Dunnett']).not_to eq([])
    end
  end

end
