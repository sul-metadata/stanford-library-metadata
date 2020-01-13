require '../apps/transform_spreadsheet/transform_spreadsheet'
require './spec_helper'

RSpec.describe Transformer do

  before(:all) do
    @source_filename = File.join(FIXTURES_DIR, 'transform_spreadsheet/test_source.xlsx')
    @map_filename = File.join(FIXTURES_DIR, 'transform_spreadsheet/test_mapping.xlsx')
    @out_filename = './public/transform_spreadsheet/output.csv'
    @transform_object = Transformer.new(@source_filename, @map_filename, @out_filename)
    @transform_process = @transform_object.transform
    @data_row = @transform_object.process_row(["A tiny book", "Small, Ellen", "50 x 50"], ["Title", "Author", "Dimensions in mm"])
    @missing_data_row = @transform_object.process_row(["A mysterious book", "", ""], ["Title", "Author", "Dimensions in mm"])
  end

  describe 'parses the mapping file:' do
    it 'creates a roo object from the mapping file' do
      expect(@transform_object.open_spreadsheet(@map_filename)).to be_a(Roo::Excelx)
    end
    it 'generates the correct output order from the mapping file' do
      expect(@transform_object.output_order).to eq(['druid', 'sourceId', 'ti1:title', 'na1:namePart', 'ro1:roleText', 'ph:extent'])
    end
    it 'identifies map fields in mapping file' do
      expect(@transform_object.map_data).to eq({"ti1:title"=>"Title", "na1:namePart"=>"Author"})
    end
    it 'identifies string fields in mapping file' do
      expect(@transform_object.string_data).to eq({"druid"=>"", "sourceId"=>"", "ro1:roleText"=>"author"})
    end
    it 'identifies complex fields in mapping file' do
      expect(@transform_object.complex_data).to eq({"ph:extent"=>"{Dimensions in mm} mm"})
    end
    it 'identifies data rules in mapping file' do
      expect(@transform_object.data_rules).to eq({"ro1:roleText"=>"Author", "ph:extent"=>"Dimensions in mm"})
    end
  end

  describe 'parses the data file:' do
    it 'creates a roo object from the data file' do
      expect(@transform_object.open_spreadsheet(@source_filename)).to be_a(Roo::Excelx)
    end
    it 'processes map fields' do
      expect(@data_row['ti1:title']).to eq('A tiny book')
    end
    it 'processes string fields' do
      expect(@data_row['ro1:roleText']).to eq('author')
    end
    it 'processes complex fields' do
      expect(@data_row['ph:extent']).to eq('50 x 50 mm')
    end
    it 'processes complex fields with missing dependency' do
      expect(@missing_data_row['ph:extent'].to_s).to eq('')
    end
    it 'processes data rules' do
      expect(@missing_data_row['ro1:roleText'].to_s).to eq('')
    end
    it 'adds unmapped columns' do
      expect(@data_row['druid'].to_s).to eq('')
    end
  end

  describe 'outputs transformed data' do
    it 'outputs correct data' do
      expect(File.read(@out_filename)).to eq(File.read(File.join(FIXTURES_DIR, 'transform_spreadsheet/transform_output.csv')))
    end
  end

end
