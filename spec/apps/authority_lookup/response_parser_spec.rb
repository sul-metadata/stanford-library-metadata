require '../apps/authority_lookup/response_parser'
require '../apps/authority_lookup/result_parser'
require '../apps/authority_lookup/authority_lookup'
require './spec_helper'

RSpec.describe ResponseParser do

  before(:all) do
    @lookup_test = AuthorityLookup.new(['Dorothy Dunnett', 'Dorothy L. Sayers'], 'LOCNAMES_RWO_LD4L_CACHE', "https://lookup.ld4l.org/authorities/search/linked_data/", parameter: "&context=true")
    query_url = @lookup_test.construct_query("Dorothy Dunnett")
    @response_test = @lookup_test.run_query(query_url)
    @response_json = File.read(File.join(FIXTURES_DIR, 'authority_lookup/response.json'))
  end

  describe 'parses response based on authority:' do
    it 'returns results when a valid authority is provided' do
      @parser_test = ResponseParser.new(@response_test, 'LOCNAMES_RWO_LD4L_CACHE')
      expect(@parser_test.parsed_response).not_to eq([])
    end
    it 'returns blank array if authority is unrecognized' do
      @parser_test = ResponseParser.new(@response_test, 'NOT_AN_AUTHORITY')
      expect(@parser_test.parsed_response).to eq([])
    end
    it 'returns expected results' do
      @parser_test = ResponseParser.new(@response_json, 'LOCNAMES_RWO_LD4L_CACHE')
      expect(@parser_test.parsed_response).to eq([{"label"=>"Dorothy Dunnett Society", "uri"=>"http://id.loc.gov/authorities/names/no2013046209"}, {"label"=>"Dorothy Dunnett Readers' Association", "uri"=>"http://id.loc.gov/authorities/names/no2008168101"}, {"label"=>"Dunnett, Dorothy", "uri"=>"http://id.loc.gov/authorities/names/n50025011"}])
    end
  end

  describe 'parses a response from LOCNAMES_RWO_LD4L_CACHE:' do
    it 'extracts data from the JSON response' do
      @parser_test = ResponseParser.new(@response_json, 'LOCNAMES_RWO_LD4L_CACHE')
      parsed_loc = @parser_test.parse_response_LOCNAMES_RWO_LD4L_CACHE
      expect(parsed_loc).to eq([{"label"=>"Dorothy Dunnett Society", "uri"=>"http://id.loc.gov/authorities/names/no2013046209"}, {"label"=>"Dorothy Dunnett Readers' Association", "uri"=>"http://id.loc.gov/authorities/names/no2008168101"}, {"label"=>"Dunnett, Dorothy", "uri"=>"http://id.loc.gov/authorities/names/n50025011"}])
    end
  end

end
