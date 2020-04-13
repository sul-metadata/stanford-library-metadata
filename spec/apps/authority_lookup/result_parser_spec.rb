require '../apps/authority_lookup/result_parser'
require './spec_helper'

RSpec.describe ResultParser do

  before(:all) do
    result_set_test = [
      {"Dorothy Dunnett" =>
        [
          {
            "label" => "Dorothy Dunnett Society",
            "uri" => "http://id.loc.gov/authorities/names/no2013046209"
          },
          {
            "label" => "Dunnett, Dorothy",
            "uri" => "http://id.loc.gov/authorities/names/n50025011"
          },
          {
            "label" => "Dunnett, Dorothy. House of Niccolò",
            "uri" => "http://id.loc.gov/authorities/names/n86732737"
          },
          {
            "label" => "Dunnett, Dorothy. Lymond chronicles",
            "uri" => "http://id.loc.gov/authorities/names/n97075542"
          }
        ]
      },
      {"Dorothy L. Sayers" =>
        [
          {
            "label" => "Sayers, Dorothy L. (Dorothy Leigh), 1893-1957. Short stories",
            "uri" => "http://id.loc.gov/authorities/names/n2003038132"
          },
          {
            "label" => "Sayers, Dorothy L. (Dorothy Leigh), 1893-1957. Correspondence. Selections",
            "uri" => "http://id.loc.gov/authorities/names/n95107609"
          },
          {
            "label" => "Sayers, Dorothy L. (Dorothy Leigh), 1893-1957. Poems. Selections",
            "uri" => "http://id.loc.gov/authorities/names/n98033744"
          },
          {
            "label" => "Sayers, Dorothy L. (Dorothy Leigh), 1893-1957. Clouds of witness",
            "uri" => "http://id.loc.gov/authorities/names/n2002076792"
          },
          {
            "label" => "Sayers, Dorothy L. (Dorothy Leigh), 1893-1957. Strong poison. Norwegian",
            "uri" => "http://id.loc.gov/authorities/names/no2002027060"
          }
        ]
      },
      {"Georgette Heyer" => [ ["uri", "id", "label"] ] },
      {"Renee Vivien" => [] }
    ]

    @outfile = './public/authority_lookup/test.txt'
    @result_parser_test = ResultParser.new(result_set_test, @outfile)
  end

  describe 'parses results for CSV:' do
    it 'generates csv' do
      expect(File.read(@outfile)).to eq(File.read(File.join(FIXTURES_DIR, 'authority_lookup/lookup_results.csv')))
    end
  end

end
