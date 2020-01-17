require '../apps/authority_lookup/authority_lookup'
require '../apps/authority_lookup/file_parser'
require './spec_helper'

RSpec.describe AuthorityLookup do

  before(:all) do
    @authority_lookup_test = AuthorityLookup.new(['Dorothy Dunnett'], 'LOCNAMES_RWO_LD4L_CACHE', 'https://lookup.ld4l.org/authorities/search/linked_data/', language: 'en', parameter: '&context=true')
  end

  describe 'exits if arguments missing:' do
    it 'exits if term list not provided' do
      expect(AuthorityLookup.new([], 'authority', 'http://example.com/').exit).to eq(true)
    end
    it 'exits if authority not provided' do
      expect(AuthorityLookup.new(['term'], '', 'http://example.com/').exit).to eq(true)
    end
    it 'exits if base URL not provided' do
      expect(AuthorityLookup.new(['term'], 'authority', nil).exit).to eq(true)
    end
  end

  describe 'parses optional arguments:' do
    it 'sets subauthority' do
      subauthority_option = AuthorityLookup.new(['term'], 'authority', 'http://example.com/', subauthority: 'naf')
      expect(subauthority_option.subauthority).to eq('naf')
    end
    it 'sets limit' do
      limit_option = AuthorityLookup.new(['term'], 'authority', 'http://example.com/', limit: 1)
      expect(limit_option.limit).to eq(1)
    end
    it 'sets language' do
      language_option = AuthorityLookup.new(['term'], 'authority', 'http://example.com/', language: 'ru')
      expect(language_option.language).to eq('ru')
    end
    it 'sets terminal parameter' do
      parameter_option = AuthorityLookup.new(['term'], 'authority', 'http://example.com/', parameter: '&context=true')
      expect(parameter_option.parameter).to eq('&context=true')
    end
  end

  describe 'prepares query:' do
    it 'encodes the search term' do
      expect(@authority_lookup_test.encode_search_term('Dorothy Dunnett')).to eq('Dorothy+Dunnett')
    end
    it 'constructs a basic query' do
      expect(@authority_lookup_test.construct_query('Dorothy Dunnett')).to eq('https://lookup.ld4l.org/authorities/search/linked_data/LOCNAMES_RWO_LD4L_CACHE?q=Dorothy+Dunnett&maxRecords=10&lang=en&context=true')
    end
    it 'constructs a query with options' do
      options_test = AuthorityLookup.new('Dorothy Dunnett', 'LOCNAMES_RWO_LD4L_CACHE', 'https://lookup.ld4l.org/authorities/search/linked_data/', subauthority: 'naf', limit: 1, language: 'ru', parameter: '&context=true')
      expect(options_test.construct_query('Dorothy Dunnett')).to eq('https://lookup.ld4l.org/authorities/search/linked_data/LOCNAMES_RWO_LD4L_CACHE/naf?q=Dorothy+Dunnett&maxRecords=1&lang=ru&context=true')
    end
  end

  describe 'returns results:' do
    it 'returns a result for a search term' do
      lookup_result = @authority_lookup_test.lookup_term('Dorothy Dunnett')
      expect(lookup_result['Dorothy Dunnett']).not_to eq([])
    end
    it 'returns results for each term in a list' do
      term_list = FileParser.new(File.join(FIXTURES_DIR, 'authority_lookup/lookup_list.txt')).terms
      expect(term_list.size).to eq(2)
      results = AuthorityLookup.new(term_list, 'LOCNAMES_RWO_LD4L_CACHE', 'https://lookup.ld4l.org/authorities/search/linked_data/', parameter: '&context=true').process_term_list
      expect(results.size).to eq(2)
    end
  end

end
