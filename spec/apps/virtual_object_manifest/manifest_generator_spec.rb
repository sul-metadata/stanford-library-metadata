require '../apps/virtual_object_manifest/manifest_generator'
require './spec_helper'

RSpec.describe ManifestGenerator do

  before(:all) do
    @outfile = File.join(PUBLIC_DIR, 'virtual_object_manifest/manifest.csv')
    @logfile = File.join(PUBLIC_DIR, 'virtual_object_manifest/log.csv')
    @statfile = File.join(PUBLIC_DIR, 'virtual_object_manifest/stats.csv')
    @manifest_test_object = ManifestGenerator.new(File.join(FIXTURES_DIR, 'virtual_object_manifest/manifest_test.xlsx'), @outfile, @logfile, @statfile)
    @manifest_test_process = @manifest_test_object.generate_manifest
    @data = @manifest_test_object.process_sheet(@manifest_test_object.sheet)
  end

  describe 'parses input data:' do
    it 'generates a ManifestSheet from the input file' do
      expect(@manifest_test_object.infile).to be_a(ManifestSheet)
    end
    it 'does not process data with validation errors' do
      manifest_errors_object = ManifestGenerator.new(File.join(FIXTURES_DIR, 'virtual_object_manifest/manifest_test_errors.xlsx'), @outfile, @logfile, @statfile)
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
      expect(@data).to have_key('hn306pf4453')
    end
    it 'processes a new child row for an existing parent' do
      expect(@data['hn306pf4453']).to include('qv868zb8723')
    end

  end

  describe 'generates output:' do
    it 'generates expected data statistics output' do
      expect(File.read(@statfile)).to eq(File.read(File.join(FIXTURES_DIR, 'virtual_object_manifest/manifest_stats.csv')))
    end
    it 'generates expected manifest output' do
      expect(File.read(@outfile)).to eq(File.read(File.join(FIXTURES_DIR, 'virtual_object_manifest/manifest.csv')))
    end
  end

end
