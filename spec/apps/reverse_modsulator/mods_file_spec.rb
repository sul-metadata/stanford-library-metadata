require '../apps/reverse_modsulator/mods_file'
require '../apps/reverse_modsulator/reverse_modsulator'
require './spec_helper'

RSpec.describe MODSFile do

  before(:all) do
    @logfile = File.join(PUBLIC_DIR, 'reverse_modsulator/log.csv')
    reverse_modsulator_test = ReverseModsulator.new(File.join(FIXTURES_DIR, 'reverse_modsulator/aa111aa1111.zip'), File.join(PUBLIC_DIR, 'reverse_modsulator/aa111aa1111.csv'), @logfile)
    template = reverse_modsulator_test.template_xml
    mods = Nokogiri::XML(File.open(File.join(FIXTURES_DIR, 'reverse_modsulator/aa111aa1111.xml')))
    @mods_file_test = MODSFile.new(mods, template, 'xmlns')
    @mods_file_test.transform_mods_file
  end

  describe 'extracts MODS data from elements:' do
    it 'extracts child element data from titleInfo/title' do
      expect(@mods_file_test.column_hash).to have_key('ti1:title')
      expect(@mods_file_test.column_hash['ti1:title']).to eq('Title')
    end
    it 'extracts child element data from titleInfo/subTitle' do
      expect(@mods_file_test.column_hash).to have_key('ti1:subTitle')
      expect(@mods_file_test.column_hash['ti1:subTitle']).to eq('subtitle')
    end
    it 'extracts element data from genre' do
      expect(@mods_file_test.column_hash).to have_key('ge1:genre')
      expect(@mods_file_test.column_hash['ge1:genre']).to eq('AAT genre')
    end
    it 'extracts element data from language text' do
      expect(@mods_file_test.column_hash).to have_key('la1:text')
      expect(@mods_file_test.column_hash['la1:text']).to eq('English')
    end
    it 'extracts element data from language code' do
      expect(@mods_file_test.column_hash).to have_key('la1:code')
      expect(@mods_file_test.column_hash['la1:code']).to eq('eng')
    end
    it 'extracts text data when code element not present' do
      expect(@mods_file_test.column_hash).to have_key('la2:text')
      expect(@mods_file_test.column_hash['la2:text']).to eq('Russian')
    end
    it 'extracts code data when text element not present' do
      expect(@mods_file_test.column_hash).to have_key('la3:code')
      expect(@mods_file_test.column_hash['la3:code']).to eq('lat')
    end
    it 'extracts element data from subject/name for name subject' do
      expect(@mods_file_test.column_hash).to have_key('sn1:p1:name')
      expect(@mods_file_test.column_hash['sn1:p1:name']).to eq('Name subject - name')
    end
    it 'extracts element data from subject/topic for name subject' do
      expect(@mods_file_test.column_hash).to have_key('sn1:p2:value')
      expect(@mods_file_test.column_hash['sn1:p2:value']).to eq('Name subject - topic')
    end
    it 'extracts element data from subject/name for name-title subject' do
      expect(@mods_file_test.column_hash).to have_key('sn2:p1:name')
      expect(@mods_file_test.column_hash['sn2:p1:name']).to eq('Name-title subject - name')
    end
    it 'extracts element data from subject/titleInfo for name-title subject' do
      expect(@mods_file_test.column_hash).to have_key('sn2:p1:title')
      expect(@mods_file_test.column_hash['sn2:p1:title']).to eq('Name-title subject - title')
    end
    it 'extracts element data from subject/topic for name-title subject' do
      expect(@mods_file_test.column_hash).to have_key('sn2:p2:value')
      expect(@mods_file_test.column_hash['sn2:p2:value']).to eq('Name-title subject - topic')
    end
    it 'extracts element data from subject/titleInfo for title subject' do
      expect(@mods_file_test.column_hash).to have_key('sn3:p1:title')
      expect(@mods_file_test.column_hash['sn3:p1:title']).to eq('Title subject - title')
    end
    it 'extracts element data from subject/topic' do
      expect(@mods_file_test.column_hash).to have_key('su1:p1:value')
      expect(@mods_file_test.column_hash['su1:p1:value']).to eq('Topic subject')
    end
    it 'extracts scale from cartographic subjects' do
      expect(@mods_file_test.column_hash).to have_key('sc1:scale')
      expect(@mods_file_test.column_hash['sc1:scale']).to eq('Scale')
    end
    it 'extracts coordinates from cartographic subjects' do
      expect(@mods_file_test.column_hash).to have_key('sc1:coordinates')
      expect(@mods_file_test.column_hash['sc1:coordinates']).to eq('Coordinates')
    end
    it 'extracts repository location' do
      expect(@mods_file_test.column_hash).to have_key('lo:repository')
      expect(@mods_file_test.column_hash['lo:repository']).to eq('Repository')
    end
    it 'extracts non-repository location' do
      expect(@mods_file_test.column_hash).to have_key('lo:physicalLocation')
      expect(@mods_file_test.column_hash['lo:physicalLocation']).to eq('Physical location')
    end
    it 'extracts primary display URL' do
      expect(@mods_file_test.column_hash).to have_key('lo:purl')
      expect(@mods_file_test.column_hash['lo:purl']).to eq('https://purl.stanford.edu/aa11aaa1111')
    end
    it 'extracts non-primary display URL' do
      expect(@mods_file_test.column_hash).to have_key('lo:url')
      expect(@mods_file_test.column_hash['lo:url']).to eq('https://example.com')
    end
    it 'extracts location/shelfLocator' do
      expect(@mods_file_test.column_hash).to have_key('lo:callNumber')
      expect(@mods_file_test.column_hash['lo:callNumber']).to eq('Shelf locator')
    end
    it 'extracts element data from first relatedItem' do
      expect(@mods_file_test.column_hash).to have_key('ri1:abstract')
      expect(@mods_file_test.column_hash['ri1:abstract']).to eq('Related item - abstract')
    end
    it 'extracts element data from additional relatedItem' do
      expect(@mods_file_test.column_hash).to have_key('ri2:title')
      expect(@mods_file_test.column_hash['ri2:title']).to eq('Another related item')
    end
    it 'extracts element data from repeated element' do
      expect(@mods_file_test.column_hash).to have_key('ge2:genre')
      expect(@mods_file_test.column_hash['ge2:genre']).to eq('TGM genre')
    end
  end

  describe 'extracts MODS data from attributes:' do
    it 'extracts attribute data from genre' do
      expect(@mods_file_test.column_hash).to have_key('ge1:authority')
      expect(@mods_file_test.column_hash['ge1:authority']).to eq('aat')
    end
    it 'extracts attribute data from language' do
      expect(@mods_file_test.column_hash).to have_key('la1:objectPart')
      expect(@mods_file_test.column_hash['la1:objectPart']).to eq('notes')
    end
    it 'extracts attribute data from language term' do
      expect(@mods_file_test.column_hash).to have_key('la1:authority')
      expect(@mods_file_test.column_hash['la1:authority']).to eq('iso639-2b')
    end
    it 'extracts attribute data from subject/name' do
      expect(@mods_file_test.column_hash).to have_key('sn1:p1:nameType')
      expect(@mods_file_test.column_hash['sn1:p1:nameType']).to eq('personal')
    end
    it 'extracts attribute data from subject/titleInfo' do
      expect(@mods_file_test.column_hash).to have_key('sn3:p1:titleType')
      expect(@mods_file_test.column_hash['sn3:p1:titleType']).to eq('uniform')
    end
    it 'extracts attribute data from subject' do
      expect(@mods_file_test.column_hash).to have_key('su1:authority')
      expect(@mods_file_test.column_hash['su1:authority']).to eq('lcsh')
    end
    it 'extracts attribute data from subject/topic' do
      expect(@mods_file_test.column_hash).to have_key('su1:p1:authority')
      expect(@mods_file_test.column_hash['su1:p1:authority']).to eq('naf')
    end
    it 'extracts attribute data from relative XPath' do
      expect(@mods_file_test.column_hash).to have_key('lo:valueURI')
      expect(@mods_file_test.column_hash['lo:valueURI']).to eq('http://id.loc.gov/authorities/names/no12345')
    end
    it 'extracts attribute data from relatedItem' do
      expect(@mods_file_test.column_hash).to have_key('ri2:type')
      expect(@mods_file_test.column_hash['ri2:type']).to eq('host')
    end
    it 'extracts attribute data from repeated element' do
      expect(@mods_file_test.column_hash).to have_key('ge2:authority')
      expect(@mods_file_test.column_hash['ge2:authority']).to eq('tgm')
    end
  end

  describe 'extracts MODS data from non-default namespace:' do
    before(:all) do
      reverse_modsulator_test_namespace = ReverseModsulator.new(File.join(FIXTURES_DIR, 'reverse_modsulator/namespace'), File.join(PUBLIC_DIR, 'reverse_modsulator/mm111mm1111.csv'), @logfile, namespace: 'mods', template_file: File.join(FIXTURES_DIR, 'reverse_modsulator/modified_template-3-4.xml'))
      template_namespace = reverse_modsulator_test_namespace.template_xml
      mods_namespace = Nokogiri::XML(File.open(File.join(FIXTURES_DIR, 'reverse_modsulator/namespace/mm111mm1111.xml')))
      @mods_file_test_namespace = MODSFile.new(mods_namespace, template_namespace, 'mods')
      @mods_file_test_namespace.transform_mods_file
    end
    it 'extracts element data with non-default namespace' do
      expect(@mods_file_test_namespace.column_hash).to have_key('ti1:title')
      expect(@mods_file_test_namespace.column_hash['ti1:title']).to eq('Title')
    end
    it 'extracts attribute data with non-default namespace' do
      expect(@mods_file_test_namespace.column_hash).to have_key('ge1:authority')
      expect(@mods_file_test_namespace.column_hash['ge1:authority']).to eq('aat')
    end
  end

end
