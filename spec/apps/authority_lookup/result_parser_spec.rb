require '../apps/authority_lookup/result_parser'

RSpec.describe ResultParser do

  before(:all) do
    result_set_test = [
      {"Dorothy Dunnett" =>
        [
          {"uri" => "http://id.loc.gov/authorities/names/no2013046209", "id" => "no2013046209", "label" => "Dorothy Dunnett Society"},
          {"uri" => "http://id.loc.gov/authorities/names/n50025011", "id" => "n 50025011", "label" => "Dunnett, Dorothy"},
          {"uri" => "http://id.loc.gov/authorities/names/n86732737", "id" => "n 86732737", "label" => "Dunnett, Dorothy. House of Niccolò"},
          {"uri" => "http://id.loc.gov/authorities/names/n97075542", "id" => "n 97075542", "label" => "Dunnett, Dorothy. Lymond chronicles"}
        ]
      },
      {"Dorothy L. Sayers" =>
        [
          {"uri" => "http://id.loc.gov/authorities/names/n2003038132", "id" => "n 2003038132", "label" => "Sayers, Dorothy L. (Dorothy Leigh), 1893-1957. Short stories"},
          {"uri" => "http://id.loc.gov/authorities/names/n95107609", "id" => "n 95107609", "label" => "Sayers, Dorothy L. (Dorothy Leigh), 1893-1957. Correspondence. Selections"},
          {"uri" => "http://id.loc.gov/authorities/names/n98033744", "id" => "n 98033744", "label" => "Sayers, Dorothy L. (Dorothy Leigh), 1893-1957. Poems. Selections"},
          {"uri" => "http://id.loc.gov/authorities/names/n2002076792", "id" => "n 2002076792", "label" => "Sayers, Dorothy L. (Dorothy Leigh), 1893-1957. Clouds of witness"},
          {"uri" => "http://id.loc.gov/authorities/names/no2002027060", "id" => "no2002027060", "label" => "Sayers, Dorothy L. (Dorothy Leigh), 1893-1957. Strong poison. Norwegian"}
        ]
      },
      {"Georgette Heyer" =>
        [
          ["uri", "id", "label"]
        ]
      },
      {"Renee Vivien" => []}
    ]

    @outfile = './public/authority_lookup/test.txt'
    @result_parser_test = ResultParser.new(result_set_test, @outfile)
  end

  describe 'parses results for CSV:' do
    it 'generates csv' do
      expect(File.read(@outfile)).to eq(File.read('./fixtures/lookup_results.csv'))
    end
  end

end
