require '../apps/virtual_object_manifest/manifest_sheet'
require './spec_helper'

RSpec.describe ManifestSheet do

  before(:all) do
    @manifest_errors_object = ManifestSheet.new(File.join(FIXTURES_DIR, 'virtual_object_manifest/manifest_test_errors.xlsx'))
    @manifest_errors_process = @manifest_errors_object.validate
  end

  describe 'parses input spreadsheet:' do
    it 'generates roo object' do
      expect(@manifest_errors_object.sheet).to be_a(Roo::Excelx)
    end
    it 'parses column headers' do
      expect(@manifest_errors_object.rows[0].keys.sort).to eq([:druid, :root, :sequence])
    end
    it 'parses column data' do
      expect(@manifest_errors_object.rows.size).to eq(235)
    end
  end

  describe 'validates data:' do
    it 'validates headers' do
      expect(@manifest_errors_object.validate_headers(['sequence', 'x'])).to eq(true)
    end
    it 'validates druid' do
      expect(@manifest_errors_object.errors).to include('Druid not recognized: zs357zh746')
    end
    it 'identifies empty cells' do
      expect(@manifest_errors_object.errors).to include('Missing value in row 14')
    end
    it 'identifies non-integer sequence values' do
      expect(@manifest_errors_object.errors).to include('Sequence value cannot be converted to integer for sw450gx6690')
    end
    it 'identifies missing parents' do
      expect(@manifest_errors_object.errors).to include('Root sc1043_01_mem_court_2 missing parent numbered 0')
    end
    it 'identifies elements not in order' do
      expect(@manifest_errors_object.errors).to include('Root sc1043_01-010 has disordered elements near 9')
    end
  end

  describe 'generates output:' do
    it 'generates expected error report' do
      expect(File.read(File.join(PUBLIC_DIR, 'virtual_object_manifest/errors.csv'))).to eq(File.read(File.join(FIXTURES_DIR, 'virtual_object_manifest/errors.csv')))
    end
  end

end
