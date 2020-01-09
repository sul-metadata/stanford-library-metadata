require '../apps/virtual_object_manifest/manifest_generator'

RSpec.describe ManifestGenerator do

  before(:all) do
    @manifest_test_object = ManifestGenerator.new('./fixtures/manifest_test.xlsx')
    @manifest_test_process = @manifest_test_object.generate_manifest
  end

  describe 'parses input data:' do
    it 'generates a ManifestSheet from the input file' do
      expect(@manifest_test_object.infile).to be_a(ManifestSheet)
    end
    it 'does not process data with validation errors' do
      manifest_errors_object = ManifestGenerator.new('./fixtures/manifest_test_errors.xlsx')
      expect(manifest_errors_object.generate_manifest).to eq(0)
    end
    it 'parses a row in the ManifestSheet' do
      @manifest_test_object.sheet.each(sequence: 'sequence', druid: 'druid') do |row|
        next if row[:druid] == 'druid'
        expect(row).to eq({:druid=>"mh613zm1032", :sequence=>"0"})
        break
      end
    end
  end

  describe 'generates manifest data:' do
    it 'processes a new parent row' do
      @manifest_test_object.sheet.each(sequence: 'sequence', druid: 'druid') do |row|
        next unless row[:druid] == 'wc326ks0006'
        @manifest_test_object.process_row(row)
        expect(@manifest_test_object.current_parent).to eq('wc326ks0006')
        break
      end
    end
    it 'processes a new child row for an existing parent' do
      @manifest_test_object.sheet.each(sequence: 'sequence', druid: 'druid') do |row|
        next unless row[:druid] == 'dw373br9638'
        @manifest_test_object.process_row(row)
        expect(@manifest_test_object.current_parent).to eq('wc326ks0006')
        break
      end
    end

  end

  describe 'generates output:' do
    it 'generates expected data statistics output' do
      expect(File.read('./public/virtual_object_manifest/stats.csv')).to eq(File.read('./fixtures/manifest_stats.csv'))
    end
    it 'generates expected manifest output' do
      expect(File.read('./public/virtual_object_manifest/manifest.csv')).to eq(File.read('./fixtures/manifest.csv'))
    end
  end

end