require '../apps/cocina_description_validator/cocina_description_validator'
require './spec_helper'
require 'json_schemer'
require 'csv'
require 'json'

RSpec.describe CocinaValidator do

  before(:all) do
    @log = File.join(PUBLIC_DIR, 'cocina_description_validator/log.csv')
    @valid = CocinaValidator.new(JSON.parse(File.read(File.join(FIXTURES_DIR, 'cocina_description_validator/hj456dt5655.json'))), @log)
    @no_errors = @valid.validate_data
    @invalid = CocinaValidator.new(JSON.parse(File.read(File.join(FIXTURES_DIR, 'cocina_description_validator/invalid.json'))), @log)
    @has_errors = @invalid.validate_data
    @errors = @invalid.identify_errors
  end

  describe 'parses schema:' do
    it 'parses a JSON schema' do
      expect(@valid.validator).to be_an_instance_of JSONSchemer::Schema::Draft6
    end
  end

  describe 'identifies errors:' do
    it 'identifies the right number of errors' do
      expect(@errors.size).to eq(2)
    end
    it 'identifies an invalid property' do
      expect(@errors[0]['type']).to match('schema')
    end
    it 'identifies an invalid data type' do
      expect(@errors[1]['type']).to match('string')
    end
    it 'identifies the location of an error' do
      expect(@errors[0]['data_pointer']).to match('/not')
    end
  end

  describe 'formats errors:' do
    it 'formats errors for output' do
      expect(@invalid.format_error(@errors[1])).to eq(['Value must be of type string', "property '/purl'"])
    end
  end

  describe 'reports errors:' do
    it 'writes errors to file' do
      expect(File.zero?(@log)).not_to be
    end
  end

  describe 'validates data:' do
    it 'returns true if data is valid' do
      expect(@valid.result).to be
    end
    it 'returns false when data is invalid' do
      expect(@invalid.result).not_to be
    end
  end

end
