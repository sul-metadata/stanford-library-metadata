require '../apps/replayable_spreadsheet_validator/replayable_spreadsheet_validator'
require './spec_helper'
require 'csv'
require 'roo'

RSpec.describe Validator do

  before(:all) do
    @csv = Validator.new(File.join(FIXTURES_DIR, 'replayable_spreadsheet_validator/test.csv'))
    @csv.validate_spreadsheet
    @csv_errors = @csv.errors.to_a.flatten
    @xlsx = Validator.new(File.join(FIXTURES_DIR, 'replayable_spreadsheet_validator/test.xlsx'))
    @xlsx.validate_spreadsheet
    @xlsx_errors = @xlsx.errors.to_a.flatten
    @non_utf8_csv = File.join(FIXTURES_DIR, 'replayable_spreadsheet_validator/test_word.csv')
    @no_header_csv = File.join(FIXTURES_DIR, 'replayable_spreadsheet_validator/no_header.csv')
    @no_header_xlsx = File.join(FIXTURES_DIR, 'replayable_spreadsheet_validator/no_header.xlsx')
    @druid_sourceid_csv = File.join(FIXTURES_DIR, 'replayable_spreadsheet_validator/druid_sourceid.csv')
    @druid_sourceid_xlsx = File.join(FIXTURES_DIR, 'replayable_spreadsheet_validator/druid_sourceid.xlsx')
    @subject_type_no_value_csv = File.join(FIXTURES_DIR, 'replayable_spreadsheet_validator/subject_type_no_value.csv')
    @subject_type_no_value_xlsx = File.join(FIXTURES_DIR, 'replayable_spreadsheet_validator/subject_type_no_value.xlsx')
    @subject_value_no_type_csv = File.join(FIXTURES_DIR, 'replayable_spreadsheet_validator/subject_value_no_type.csv')
    @subject_value_no_type_xlsx = File.join(FIXTURES_DIR, 'replayable_spreadsheet_validator/subject_value_no_type.xlsx')
    @date_content_csv = File.join(FIXTURES_DIR, 'replayable_spreadsheet_validator/date_content.csv')
    @date_content_xlsx = File.join(FIXTURES_DIR, 'replayable_spreadsheet_validator/date_content.xlsx')
  end

  describe 'validates file extension:' do
    it 'identifies csv file extension' do
      expect(@csv.validate_file_extension).not_to be(true)
    end
    it 'identifies xls file extension' do
      expect(Validator.new('file.xls').validate_file_extension).not_to be(true)
    end
    it 'identifies xlsx file extension' do
      expect(@xlsx.validate_file_extension).not_to be(true)
    end
    it 'reports invalid file extension' do
      expect(Validator.new('file.xxx').validate_file_extension).to be(true)
    end
    it 'reports missing file extension' do
      expect(Validator.new('file').validate_file_extension).to be(true)
    end
  end

  describe 'validates file encoding:' do
    # does not apply to xlsx
    it 'recognizes utf-8 file encoding for csv' do
      expect(@csv.validate_file_encoding).not_to be(true)
    end
    it 'recognizes non-utf-8 file encoding for csv' do
      expect(Validator.new(@non_utf8_csv).validate_file_encoding).to be(true)
    end
  end

  #describe 'validates file open:'

  describe 'validates headers:' do
    it 'identifies header row for csv' do
      expect(@csv.header_row_terms).not_to eq([])
    end
    it 'identifies header row for xlsx' do
      expect(@xlsx.header_row_terms).not_to eq([])
    end
    it 'reports header row index for csv' do
      expect(@csv.header_row_index).to eq(0)
    end
    it 'reports header row index for xlsx' do
      expect(@xlsx.header_row_index).to eq(0)
    end
    it 'reports missing header row for csv' do
      no_header_csv = Validator.new(@no_header_csv)
      no_header_csv.validate_headers
      expect(no_header_csv.exit).to eq(true)
    end
    it 'reports missing header row for xlsx' do
      no_header_csv = Validator.new(@no_header_xlsx)
      no_header_csv.validate_headers
      expect(no_header_csv.exit).to eq(true)
    end
    # it reports invalid characters in header row
    it 'reports duplicate headers for csv' do
      expect(@csv_errors).to include('Contains duplicate headers')
    end
    it 'reports duplicate headers for xlsx' do
      expect(@xlsx_errors).to include('Contains duplicate headers')
    end
    it 'reports headers not in modsulator template for csv' do
      expect(@csv_errors).to include('Header not in XML template')
    end
    it 'reports headers not in modsulator template for xlsx' do
      expect(@xlsx_errors).to include('Header not in XML template')
    end
    it 'reports missing title header for csv' do
      no_title_csv = Validator.new(@druid_sourceid_csv)
      no_title_csv.validate_headers
      expect(no_title_csv.errors.to_a.flatten).to include('Missing required column')
    end
    it 'reports missing title header for xlsx' do
      no_title_xlsx = Validator.new(@druid_sourceid_xlsx)
      no_title_xlsx.validate_headers
      expect(no_title_xlsx.errors.to_a.flatten).to include('Missing required column')
    end
    it 'reports missing type of resource header for csv' do
      no_type_csv = Validator.new(@druid_sourceid_csv)
      no_type_csv.validate_headers
      expect(no_type_csv.errors.to_a.flatten).to include('Recommended column missing')
    end
    it 'reports missing type of resource header for xlsx' do
      no_type_xlsx = Validator.new(@druid_sourceid_xlsx)
      no_type_xlsx.validate_headers
      expect(no_type_xlsx.errors.to_a.flatten).to include('Recommended column missing')
    end
    it 'reports missing subject value header for csv' do
      subject_type_no_value_csv = Validator.new(@subject_type_no_value_csv)
      subject_type_no_value_csv.validate_headers
      expect(subject_type_no_value_csv.errors.to_a.flatten).to include('Missing subject value column header for su1:p1:type')
    end
    it 'reports missing subject value header for xlsx' do
      subject_type_no_value_xlsx = Validator.new(@subject_type_no_value_xlsx)
      subject_type_no_value_xlsx.validate_headers
      expect(subject_type_no_value_xlsx.errors.to_a.flatten).to include('Missing subject value column header for su1:p1:type')
    end
    it 'reports missing subject type header for csv' do
      subject_value_no_type_csv = Validator.new(@subject_value_no_type_csv)
      subject_value_no_type_csv.validate_headers
      expect(subject_value_no_type_csv.errors.to_a.flatten).to include('Missing subject type column header for su1:p1:value')
    end
    it 'reports missing subject type header for xlsx' do
      subject_value_no_type_xlsx = Validator.new(@subject_value_no_type_xlsx)
      subject_value_no_type_xlsx.validate_headers
      expect(subject_value_no_type_xlsx.errors.to_a.flatten).to include('Missing subject type column header for su1:p1:value')
    end
    it 'identifies subject value and type indexes for csv' do
      expect(@csv.value_type_indexes[7]).to eq(8)
    end
    it 'identifies subject value and type indexes for xlsx' do
      expect(@xlsx.value_type_indexes[7]).to eq(8)
    end
  end

  describe 'validates rows:' do
    it 'selects title type headers for csv' do
      expect(@csv.selected_headers['title_type']).to eq(['ti2:type', 'ti3:type'])
    end
    it 'selects title type headers for xlsx' do
      expect(@xlsx.selected_headers['title_type']).to eq(['ti2:type', 'ti3:type'])
    end
    it 'selects name type headers for csv' do
      expect(@csv.selected_headers['name_type']).to eq(['na1:type', 'na2:type'])
    end
    it 'selects name type headers for xlsx' do
      expect(@xlsx.selected_headers['name_type']).to eq(['na1:type', 'na2:type'])
    end
    it 'selects type of resource headers and not manuscript header for csv' do
      expect(@csv.selected_headers['type_of_resource']).to eq(['ty1:typeOfResource'])
    end
    it 'selects type of resource headers and not manuscript header for xlsx' do
      expect(@xlsx.selected_headers['type_of_resource']).to eq(['ty1:typeOfResource'])
    end
    it 'selects issuance header for csv' do
      expect(@csv.selected_headers['issuance']).to eq(['or2:issuance'])
    end
    it 'selects issuance header for xlsx' do
      expect(@xlsx.selected_headers['issuance']).to eq(['or2:issuance'])
    end
  end

  describe 'gets date headers:' do
    it 'gets grouped date headers for csv' do
      expect(@csv.get_date_headers).to include('dt:' => {
        'dateCreated' => [
          'dt:dateCreated',
          'dt:dateCreatedKeyDate',
          'dt:dateCreatedEncoding',
          'dt:dateCreatedQualifier',
          'dt:dateCreatedPoint',
          'dt:dateCreated2',
          'dt:dateCreated2Qualifier',
          'dt:dateCreated2Point',
          'dt:dateCreated3',
          'dt:dateCreated3KeyDate',
          'dt:dateCreated3Encoding',
          'dt:dateCreated3Qualifier'
          ],
          'dateIssued' => [
            'dt:dateIssued',
            'dt:dateIssuedKeyDate',
            'dt:dateIssuedEncoding',
            'dt:dateIssuedQualifier',
            'dt:dateIssuedPoint',
            'dt:dateIssued2',
            'dt:dateIssued2Qualifier',
            'dt:dateIssued2Point',
            'dt:dateIssued3',
            'dt:dateIssued3KeyDate',
            'dt:dateIssued3Encoding',
            'dt:dateIssued3Qualifier'
          ],
          'copyrightDate' => [],
          'dateCaptured' => [],
          'dateOther' => []
        })
    end
    it 'gets grouped date headers for xlsx' do
      expect(@xlsx.get_date_headers).to include('dt:' => {
        'dateCreated' => [
          'dt:dateCreated',
          'dt:dateCreatedKeyDate',
          'dt:dateCreatedEncoding',
          'dt:dateCreatedQualifier',
          'dt:dateCreatedPoint',
          'dt:dateCreated2',
          'dt:dateCreated2Qualifier',
          'dt:dateCreated2Point',
          'dt:dateCreated3',
          'dt:dateCreated3KeyDate',
          'dt:dateCreated3Encoding',
          'dt:dateCreated3Qualifier'
          ],
          'dateIssued' => [
            'dt:dateIssued',
            'dt:dateIssuedKeyDate',
            'dt:dateIssuedEncoding',
            'dt:dateIssuedQualifier',
            'dt:dateIssuedPoint',
            'dt:dateIssued2',
            'dt:dateIssued2Qualifier',
            'dt:dateIssued2Point',
            'dt:dateIssued3',
            'dt:dateIssued3KeyDate',
            'dt:dateIssued3Encoding',
            'dt:dateIssued3Qualifier'
          ],
          'copyrightDate' => [],
          'dateCaptured' => [],
          'dateOther' => []
        })
    end
  end

  describe 'processes row:' do
    it 'identifies druid for csv' do
      expect(@csv.druids).to include('aa111aa1111')
    end
    it 'identifies druid for xlsx' do
      expect(@xlsx.druids).to include('aa111aa1111')
    end
    it 'reports blank druid for csv' do
      expect(@csv_errors).to include('Missing druid')
    end
    it 'reports blank druid for xlsx' do
      expect(@xlsx_errors).to include('Missing druid')
    end
  end

  describe 'reports blank row:' do
    it 'reports blank row for csv' do
      expect(@csv.report_blank_row([nil,""," "], 0)).to eq(true)
    end
    it 'reports blank row for xlsx' do
      expect(@xlsx.report_blank_row([nil,""," "], 0)).to eq(true)
    end
    it 'identifies non-blank row for csv' do
      expect(@csv.report_blank_row(["data",""," "], 0)).to eq(false)
    end
    it 'identifies non-blank row for xlsx' do
      expect(@xlsx.report_blank_row(["data",""," "], 0)).to eq(false)
    end
  end

  describe 'validates druid:' do
    it 'reports invalid druid for csv' do
      expect(@csv_errors).to include('Invalid druid')
    end
    it 'reports invalid druid for xlsx' do
      expect(@xlsx_errors).to include('Invalid druid')
    end
    it 'identifies valid druid for csv' do
      expect(@csv.druid_is_valid_pattern?('aa111aa1111')).to eq(true)
    end
    it 'identifies valid druid for xlsx' do
      expect(@xlsx.druid_is_valid_pattern?('aa111aa1111')).to eq(true)
    end
  end

  describe 'validates cells:' do
    it 'identifies missing source IDs for csv' do
      expect(@csv_errors).to include("B2, B4")
    end
    it 'identifies missing source IDs for xlsx' do
      expect(@xlsx_errors).to include("B2, B4")
    end
  end

  # describe 'validate_characters' do
    # waiting for example fixtures
    # it reports line breaks in cell text
    # it reports control characters in cell text

  describe 'validates xlsx cell types' do
    it 'reports non-string cell formats for xlsx' do
      expect(@xlsx_errors).to include("Non-text Excel formatting: Date")
    end
  end

  describe 'reports duplicate druids:' do
    it 'reports duplicate druids for csv' do
      expect(@csv_errors).to include('Duplicate druids')
    end
    it 'reports duplicate druids for xlsx' do
      expect(@xlsx_errors).to include('Duplicate druids')
    end
  end

  describe 'reports missing source ids:' do
    it 'reports missing source id for csv' do
      expect(@csv_errors).to include('Blank source ID')
    end
    it 'reports missing source id for xlsx' do
      expect(@xlsx_errors).to include('Blank source ID')
    end
  end

  describe 'reports duplicate source ids:' do
    it 'reports duplicate source ids for csv' do
      expect(@csv_errors).to include('Duplicate source IDs')
    end
    it 'reports duplicate source ids for xlsx' do
      expect(@xlsx_errors).to include('Duplicate source IDs')
    end
  end

  describe 'reports data with no header:' do
    it 'reports data with no header within the spreadsheet for csv' do
      expect(@csv_errors).to include('Data present in column without header')
    end
    it 'reports data with no header within the spreadsheet for xlsx' do
      expect(@xlsx_errors).to include('Data present in column without header')
    end
    # CSV counts empty cells at end of row as part of header
    it 'reports data with no header at the end of the spreadsheet for xlsx' do
      expect(@xlsx_errors).to include('Data present in column without header at end of row')
    end
  end

  describe 'identifies and reports formula errors:' do
    it 'reports n/a error for csv' do
      expect(@csv.formula_errors['na']).to eq(['D4'])
    end
    it 'reports n/a error for xlsx' do
      expect(@xlsx.formula_errors['na']).to eq(['D4'])
    end
    it 'reports ref error for csv' do
      expect(@csv.formula_errors['ref']).to eq(['E4'])
    end
    it 'reports ref error for xlsx' do
      expect(@xlsx.formula_errors['ref']).to eq(['E4'])
    end
    it 'reports 0 value for csv' do
      expect(@csv.formula_errors['zero']).to eq(['H4'])
    end
    it 'reports 0 value for xlsx' do
      expect(@xlsx.formula_errors['zero']).to eq(['G4', 'H4'])
    end
    it 'reports name error for csv' do
      expect(@csv.formula_errors['name']).to eq(['I4'])
    end
    it 'reports name error for xlsx' do
      expect(@xlsx.formula_errors['name']).to eq(['I4'])
    end
    it 'reports value error for csv' do
      expect(@csv.formula_errors['value']).to eq(['J4'])
    end
    it 'reports value error for xlsx' do
      expect(@xlsx.formula_errors['value']).to eq(['J4'])
    end
    it 'reports the correct number of formula errors for csv' do
      expect(@csv.formula_errors.values.flatten.size).to eq(5)
    end
    it 'reports the correct number of formula errors for xlsx' do
      expect(@xlsx.formula_errors.values.flatten.size).to eq(6)
    end
  end

  describe 'validates title:' do
    it 'reports missing title for csv' do
      expect(@csv_errors).to include('Blank ti1:title')
    end
    it 'reports missing title for xlsx' do
      expect(@xlsx_errors).to include('Blank ti1:title')
    end
    it 'reports invalid title type term for csv' do
      expect(@csv_errors).to include('Invalid term "bad type" in ti3:type')
    end
    it 'reports invalid title type term for xlsx' do
      expect(@xlsx_errors).to include('Invalid term "bad type" in ti3:type')
    end
  end

  describe 'validates name:' do
    it 'reports invalid name type term for csv' do
      expect(@csv_errors).to include('Invalid term "fictional" in na1:type')
    end
    it 'reports invalid name type term for xlsx' do
      expect(@xlsx_errors).to include('Invalid term "fictional" in na1:type')
    end
    it 'reports invalid name usage term for csv' do
      expect(@csv_errors).to include('Invalid term "secondary" in na1:usage')
    end
    it 'reports invalid name usage term for xlsx' do
      expect(@xlsx_errors).to include('Invalid term "secondary" in na1:usage')
    end
  end

  describe 'validates type of resource:' do
    it 'reports missing type of resource value for csv' do
      expect(@csv_errors).to include('Blank ty1:typeOfResource')
    end
    it 'reports missing type of resource value for xlsx' do
      expect(@xlsx_errors).to include('Blank ty1:typeOfResource')
    end
    it 'reports invalid type of resource term for csv' do
      expect(@csv_errors).to include('Invalid term "software" in ty1:typeOfResource')
    end
    it 'reports invalid type of resource term for xlsx' do
      expect(@xlsx_errors).to include('Invalid term "software" in ty1:typeOfResource')
    end
    it 'reports invalid manuscript term for csv' do
      expect(@csv_errors).to include('Invalid term "no" in ty1:manuscript')
    end
    it 'reports invalid manuscript term for xlsx' do
      expect(@xlsx_errors).to include('Invalid term "no" in ty1:manuscript')
    end
  end

  describe 'validates date:' do
    it 'reports multiple key dates for csv' do
      expect(@csv_errors).to include('Multiple key dates declared')
    end
    it 'reports multiple key dates for xlsx' do
      expect(@xlsx_errors).to include('Multiple key dates declared')
    end
    it 'reports missing key date for csv' do
      expect(@csv_errors).to include('No key date declared')
    end
    it 'reports missing key date for xlsx' do
      expect(@xlsx_errors).to include('No key date declared')
    end
  end

  describe 'gets current date headers and values:' do
    before(:all) do
      date_validator_csv = Validator.new(@date_content_csv)
      date_validator_csv.validate_spreadsheet
      date_headers_csv = date_validator_csv.selected_headers['dates']
      data_row_csv = CSV.new(File.open(@date_content_csv)).read[1]
      @dt_date_created_headers_csv, @dt_date_created_values_csv = date_validator_csv.get_current_date_headers_and_values('dt:', 'dateCreated', date_headers_csv['dt:']['dateCreated'], data_row_csv)
      @dt_date_issued_headers_csv, @dt_date_issued_values_csv = date_validator_csv.get_current_date_headers_and_values('dt:', 'dateIssued', date_headers_csv['dt:']['dateIssued'], data_row_csv)
      @or2_date_captured_headers_csv, @or2_date_captured_values_csv = date_validator_csv.get_current_date_headers_and_values('or2:dt:', 'dateCaptured', date_headers_csv['or2:dt:']['dateCaptured'], data_row_csv)
      @or2_copyright_date_headers_csv, @or2_copyright_date_values_csv = date_validator_csv.get_current_date_headers_and_values('or2:dt:', 'copyrightDate', date_headers_csv['or2:dt:']['copyrightDate'], data_row_csv)
      @or3_date_other_headers_csv, @or3_date_other_values_csv = date_validator_csv.get_current_date_headers_and_values('or3:dt:', 'dateOther', date_headers_csv['or3:dt:']['dateOther'], data_row_csv)
      date_validator_xlsx = Validator.new(@date_content_xlsx)
      date_validator_xlsx.validate_spreadsheet
      date_headers_xlsx = date_validator_xlsx.selected_headers['dates']
      data_row_xlsx = Roo::Excelx.new(File.open(@date_content_xlsx)).row(2)
      @dt_date_created_headers_xlsx, @dt_date_created_values_xlsx = date_validator_xlsx.get_current_date_headers_and_values('dt:', 'dateCreated', date_headers_xlsx['dt:']['dateCreated'], data_row_xlsx)
      @dt_date_issued_headers_xlsx, @dt_date_issued_values_xlsx = date_validator_xlsx.get_current_date_headers_and_values('dt:', 'dateIssued', date_headers_xlsx['dt:']['dateIssued'], data_row_xlsx)
      @or2_date_captured_headers_xlsx, @or2_date_captured_values_xlsx = date_validator_xlsx.get_current_date_headers_and_values('or2:dt:', 'dateCaptured', date_headers_xlsx['or2:dt:']['dateCaptured'], data_row_xlsx)
      @or2_copyright_date_headers_xlsx, @or2_copyright_date_values_xlsx = date_validator_xlsx.get_current_date_headers_and_values('or2:dt:', 'copyrightDate', date_headers_xlsx['or2:dt:']['copyrightDate'], data_row_xlsx)
      @or3_date_other_headers_xlsx, @or3_date_other_values_xlsx = date_validator_xlsx.get_current_date_headers_and_values('or3:dt:', 'dateOther', date_headers_xlsx['or3:dt:']['dateOther'], data_row_xlsx)
    end
    it 'gets current dt:dateCreated headers for csv' do
      expect(@dt_date_created_headers_csv).to eq(
        {
          "date1" => "dt:dateCreated",
          "date1_point" => "dt:dateCreatedPoint",
          "date1_qualifier" => "dt:dateCreatedQualifier",
          "date2" => "dt:dateCreated2",
          "date2_point" => "dt:dateCreated2Point",
          "date2_qualifier" => "dt:dateCreated2Qualifier",
          "date3" => "dt:dateCreated3",
          "date3_encoding" => "dt:dateCreated3Encoding",
          "date3_key_date" => "dt:dateCreated3KeyDate",
          "date3_qualifier" => "dt:dateCreated3Qualifier",
          "encoding" => "dt:dateCreatedEncoding",
          "key_date" => "dt:dateCreatedKeyDate"
        }
      )
    end
    it 'gets current dt:dateCreated headers for xlsx' do
      expect(@dt_date_created_headers_xlsx).to eq(
        {
          "date1" => "dt:dateCreated",
          "date1_point" => "dt:dateCreatedPoint",
          "date1_qualifier" => "dt:dateCreatedQualifier",
          "date2" => "dt:dateCreated2",
          "date2_point" => "dt:dateCreated2Point",
          "date2_qualifier" => "dt:dateCreated2Qualifier",
          "date3" => "dt:dateCreated3",
          "date3_encoding" => "dt:dateCreated3Encoding",
          "date3_key_date" => "dt:dateCreated3KeyDate",
          "date3_qualifier" => "dt:dateCreated3Qualifier",
          "encoding" => "dt:dateCreatedEncoding",
          "key_date" => "dt:dateCreatedKeyDate"
        }
      )
    end
    it 'gets current dt:dateCreated values for csv' do
      expect(@dt_date_created_values_csv).to eq(
        {
          "date1" => "dt:dateCreated_value",
          "date1_point" => "dt:dateCreatedPoint_value",
          "date1_qualifier" => "dt:dateCreatedQualifier_value",
          "date2" => "dt:dateCreated2_value",
          "date2_point" => "dt:dateCreated2Point_value",
          "date2_qualifier" => "dt:dateCreated2Qualifier_value",
          "date3" => "dt:dateCreated3_value",
          "date3_encoding" => "dt:dateCreated3Encoding_value",
          "date3_key_date" => "dt:dateCreated3KeyDate_value",
          "date3_qualifier" => "dt:dateCreated3Qualifier_value",
          "encoding" => "dt:dateCreatedEncoding_value",
          "key_date" => "dt:dateCreatedKeyDate_value"
        }
      )
    end
    it 'gets current dt:dateCreated values for xlsx' do
      expect(@dt_date_created_values_xlsx).to eq(
        {
          "date1" => "dt:dateCreated_value",
          "date1_point" => "dt:dateCreatedPoint_value",
          "date1_qualifier" => "dt:dateCreatedQualifier_value",
          "date2" => "dt:dateCreated2_value",
          "date2_point" => "dt:dateCreated2Point_value",
          "date2_qualifier" => "dt:dateCreated2Qualifier_value",
          "date3" => "dt:dateCreated3_value",
          "date3_encoding" => "dt:dateCreated3Encoding_value",
          "date3_key_date" => "dt:dateCreated3KeyDate_value",
          "date3_qualifier" => "dt:dateCreated3Qualifier_value",
          "encoding" => "dt:dateCreatedEncoding_value",
          "key_date" => "dt:dateCreatedKeyDate_value"
        }
      )
    end
    it 'gets current dt:dateIssued headers for csv' do
      expect(@dt_date_issued_headers_csv).to eq(
        {
          "date1" => "dt:dateIssued",
          "date1_point" => "dt:dateIssuedPoint",
          "date1_qualifier" => "dt:dateIssuedQualifier",
          "date2" => "dt:dateIssued2",
          "date2_point" => "dt:dateIssued2Point",
          "date2_qualifier" => "dt:dateIssued2Qualifier",
          "date3" => "dt:dateIssued3",
          "date3_encoding" => "dt:dateIssued3Encoding",
          "date3_key_date" => "dt:dateIssued3KeyDate",
          "date3_qualifier" => "dt:dateIssued3Qualifier",
          "encoding" => "dt:dateIssuedEncoding",
          "key_date" => "dt:dateIssuedKeyDate"
        }
      )
    end
    it 'gets current dt:dateIssued headers for xlsx' do
      expect(@dt_date_issued_headers_xlsx).to eq(
        {
          "date1" => "dt:dateIssued",
          "date1_point" => "dt:dateIssuedPoint",
          "date1_qualifier" => "dt:dateIssuedQualifier",
          "date2" => "dt:dateIssued2",
          "date2_point" => "dt:dateIssued2Point",
          "date2_qualifier" => "dt:dateIssued2Qualifier",
          "date3" => "dt:dateIssued3",
          "date3_encoding" => "dt:dateIssued3Encoding",
          "date3_key_date" => "dt:dateIssued3KeyDate",
          "date3_qualifier" => "dt:dateIssued3Qualifier",
          "encoding" => "dt:dateIssuedEncoding",
          "key_date" => "dt:dateIssuedKeyDate"
        }
      )
    end
    it 'gets current dt:dateIssued values for csv' do
      expect(@dt_date_issued_values_csv).to eq(
        {
          "date1" => "dt:dateIssued_value",
          "date1_point" => "dt:dateIssuedPoint_value",
          "date1_qualifier" => "dt:dateIssuedQualifier_value",
          "date2" => "dt:dateIssued2_value",
          "date2_point" => "dt:dateIssued2Point_value",
          "date2_qualifier" => "dt:dateIssued2Qualifier_value",
          "date3" => "dt:dateIssued3_value",
          "date3_encoding" => "dt:dateIssued3Encoding_value",
          "date3_key_date" => "dt:dateIssued3KeyDate_value",
          "date3_qualifier" => "dt:dateIssued3Qualifier_value",
          "encoding" => "dt:dateIssuedEncoding_value",
          "key_date" => "dt:dateIssuedKeyDate_value"
        }
      )
    end
    it 'gets current dt:dateIssued values for xlsx' do
      expect(@dt_date_issued_values_xlsx).to eq(
        {
          "date1" => "dt:dateIssued_value",
          "date1_point" => "dt:dateIssuedPoint_value",
          "date1_qualifier" => "dt:dateIssuedQualifier_value",
          "date2" => "dt:dateIssued2_value",
          "date2_point" => "dt:dateIssued2Point_value",
          "date2_qualifier" => "dt:dateIssued2Qualifier_value",
          "date3" => "dt:dateIssued3_value",
          "date3_encoding" => "dt:dateIssued3Encoding_value",
          "date3_key_date" => "dt:dateIssued3KeyDate_value",
          "date3_qualifier" => "dt:dateIssued3Qualifier_value",
          "encoding" => "dt:dateIssuedEncoding_value",
          "key_date" => "dt:dateIssuedKeyDate_value"
        }
      )
    end
    it 'gets current or2:dt:dateCaptured headers for csv' do
      expect(@or2_date_captured_headers_csv).to eq(
        {
          "date1" => "or2:dt:dateCaptured",
          "date1_point" => "or2:dt:dateCapturedPoint",
          "date1_qualifier" => "or2:dt:dateCapturedQualifier",
          "date2" => "or2:dt:dateCaptured2",
          "date2_point" => "or2:dt:dateCaptured2Point",
          "date2_qualifier" => "or2:dt:dateCaptured2Qualifier",
          "encoding" => "or2:dt:dateCapturedEncoding",
          "key_date" => "or2:dt:dateCapturedKeyDate"
        }
      )
    end
    it 'gets current or2:dt:dateCaptured headers for xlsx' do
      expect(@or2_date_captured_headers_xlsx).to eq(
        {
          "date1" => "or2:dt:dateCaptured",
          "date1_point" => "or2:dt:dateCapturedPoint",
          "date1_qualifier" => "or2:dt:dateCapturedQualifier",
          "date2" => "or2:dt:dateCaptured2",
          "date2_point" => "or2:dt:dateCaptured2Point",
          "date2_qualifier" => "or2:dt:dateCaptured2Qualifier",
          "encoding" => "or2:dt:dateCapturedEncoding",
          "key_date" => "or2:dt:dateCapturedKeyDate"
        }
      )
    end
    it 'gets current or2:dt:dateCaptured values for csv' do
      expect(@or2_date_captured_values_csv).to eq(
        {
          "date1" => "or2:dt:dateCaptured_value",
          "date1_point" => "or2:dt:dateCapturedPoint_value",
          "date1_qualifier" => "or2:dt:dateCapturedQualifier_value",
          "date2" => "or2:dt:dateCaptured2_value",
          "date2_point" => "or2:dt:dateCaptured2Point_value",
          "date2_qualifier" => "or2:dt:dateCaptured2Qualifier_value",
          "date3" => "",
          "date3_encoding" => "",
          "date3_key_date" => "",
          "date3_qualifier" => "",
          "encoding" => "or2:dt:dateCapturedEncoding_value",
          "key_date" => "or2:dt:dateCapturedKeyDate_value"
        }
      )
    end
    it 'gets current or2:dt:dateCaptured values for xlsx' do
      expect(@or2_date_captured_values_xlsx).to eq(
        {
          "date1" => "or2:dt:dateCaptured_value",
          "date1_point" => "or2:dt:dateCapturedPoint_value",
          "date1_qualifier" => "or2:dt:dateCapturedQualifier_value",
          "date2" => "or2:dt:dateCaptured2_value",
          "date2_point" => "or2:dt:dateCaptured2Point_value",
          "date2_qualifier" => "or2:dt:dateCaptured2Qualifier_value",
          "date3" => "",
          "date3_encoding" => "",
          "date3_key_date" => "",
          "date3_qualifier" => "",
          "encoding" => "or2:dt:dateCapturedEncoding_value",
          "key_date" => "or2:dt:dateCapturedKeyDate_value"
        }
      )
    end
    it 'gets current or2:dt:copyrightDate headers for csv' do
      expect(@or2_copyright_date_headers_csv).to eq(
        {
          "date1" => "or2:dt:copyrightDate",
          "date1_point" => "or2:dt:copyrightDatePoint",
          "date1_qualifier" => "or2:dt:copyrightDateQualifier",
          "date2" => "or2:dt:copyrightDate2",
          "date2_point" => "or2:dt:copyrightDate2Point",
          "date2_qualifier" => "or2:dt:copyrightDate2Qualifier",
          "encoding" => "or2:dt:copyrightDateEncoding",
          "key_date" => "or2:dt:copyrightDateKeyDate"
        }
      )
    end
    it 'gets current or2:dt:copyrightDate headers for xlsx' do
      expect(@or2_copyright_date_headers_xlsx).to eq(
        {
          "date1" => "or2:dt:copyrightDate",
          "date1_point" => "or2:dt:copyrightDatePoint",
          "date1_qualifier" => "or2:dt:copyrightDateQualifier",
          "date2" => "or2:dt:copyrightDate2",
          "date2_point" => "or2:dt:copyrightDate2Point",
          "date2_qualifier" => "or2:dt:copyrightDate2Qualifier",
          "encoding" => "or2:dt:copyrightDateEncoding",
          "key_date" => "or2:dt:copyrightDateKeyDate"
        }
      )
    end
    it 'gets current or2:dt:copyrightDate values for csv' do
      expect(@or2_copyright_date_values_csv).to eq(
        {
          "date1" => "or2:dt:copyrightDate_value",
          "date1_point" => "or2:dt:copyrightDatePoint_value",
          "date1_qualifier" => "or2:dt:copyrightDateQualifier_value",
          "date2" => "or2:dt:copyrightDate2_value",
          "date2_point" => "or2:dt:copyrightDate2Point_value",
          "date2_qualifier" => "or2:dt:copyrightDate2Qualifier_value",
          "date3" => "",
          "date3_encoding" => "",
          "date3_key_date" => "",
          "date3_qualifier" => "",
          "encoding" => "or2:dt:copyrightDateEncoding_value",
          "key_date" => "or2:dt:copyrightDateKeyDate_value"
        }
      )
    end
    it 'gets current or2:dt:copyrightDate values for xlsx' do
      expect(@or2_copyright_date_values_xlsx).to eq(
        {
          "date1" => "or2:dt:copyrightDate_value",
          "date1_point" => "or2:dt:copyrightDatePoint_value",
          "date1_qualifier" => "or2:dt:copyrightDateQualifier_value",
          "date2" => "or2:dt:copyrightDate2_value",
          "date2_point" => "or2:dt:copyrightDate2Point_value",
          "date2_qualifier" => "or2:dt:copyrightDate2Qualifier_value",
          "date3" => "",
          "date3_encoding" => "",
          "date3_key_date" => "",
          "date3_qualifier" => "",
          "encoding" => "or2:dt:copyrightDateEncoding_value",
          "key_date" => "or2:dt:copyrightDateKeyDate_value"
        }
      )
    end
    it 'gets current or3:dt:dateOther headers for csv' do
      expect(@or3_date_other_headers_csv).to eq(
        {
          "date1" => "or3:dt:dateOther",
          "date1_point" => "or3:dt:dateOtherPoint",
          "date1_qualifier" => "or3:dt:dateOtherQualifier",
          "date2" => "or3:dt:dateOther2",
          "date2_point" => "or3:dt:dateOther2Point",
          "date2_qualifier" => "or3:dt:dateOther2Qualifier",
          "encoding" => "or3:dt:dateOtherEncoding",
          "key_date" => "or3:dt:dateOtherKeyDate"
        }
      )
    end
    it 'gets current or3:dt:dateOther headers for xlsx' do
      expect(@or3_date_other_headers_xlsx).to eq(
        {
          "date1" => "or3:dt:dateOther",
          "date1_point" => "or3:dt:dateOtherPoint",
          "date1_qualifier" => "or3:dt:dateOtherQualifier",
          "date2" => "or3:dt:dateOther2",
          "date2_point" => "or3:dt:dateOther2Point",
          "date2_qualifier" => "or3:dt:dateOther2Qualifier",
          "encoding" => "or3:dt:dateOtherEncoding",
          "key_date" => "or3:dt:dateOtherKeyDate"
        }
      )
    end
    it 'gets current or3:dt:dateOther values for csv' do
      expect(@or3_date_other_values_csv).to eq(
        {
          "date1" => "or3:dt:dateOther_value",
          "date1_point" => "or3:dt:dateOtherPoint_value",
          "date1_qualifier" => "or3:dt:dateOtherQualifier_value",
          "date2" => "or3:dt:dateOther2_value",
          "date2_point" => "or3:dt:dateOther2Point_value",
          "date2_qualifier" => "or3:dt:dateOther2Qualifier_value",
          "date3" => "",
          "date3_encoding" => "",
          "date3_key_date" => "",
          "date3_qualifier" => "",
          "encoding" => "or3:dt:dateOtherEncoding_value",
          "key_date" => "or3:dt:dateOtherKeyDate_value"
        }
      )
    end
    it 'gets current or3:dt:dateOther values for xlsx' do
      expect(@or3_date_other_values_xlsx).to eq(
        {
          "date1" => "or3:dt:dateOther_value",
          "date1_point" => "or3:dt:dateOtherPoint_value",
          "date1_qualifier" => "or3:dt:dateOtherQualifier_value",
          "date2" => "or3:dt:dateOther2_value",
          "date2_point" => "or3:dt:dateOther2Point_value",
          "date2_qualifier" => "or3:dt:dateOther2Qualifier_value",
          "date3" => "",
          "date3_encoding" => "",
          "date3_key_date" => "",
          "date3_qualifier" => "",
          "encoding" => "or3:dt:dateOtherEncoding_value",
          "key_date" => "or3:dt:dateOtherKeyDate_value"
        }
      )
    end
  end

  describe 'reports invalid date values:' do
    it 'reports invalid key date term for csv' do
      expect(@csv_errors).to include('Invalid term "no" in dt:dateCreatedKeyDate')
    end
    it 'reports invalid key date term for xlsx' do
      expect(@xlsx_errors).to include('Invalid term "no" in dt:dateCreatedKeyDate')
    end
    it 'reports invalid date qualifier term for csv' do
      expect(@csv_errors).to include('Invalid term "circa" in dt:dateCreatedQualifier')
    end
    it 'reports invalid date qualifier term for xlsx' do
      expect(@xlsx_errors).to include('Invalid term "circa" in dt:dateCreatedQualifier')
    end
    it 'reports invalid date point term for csv' do
      expect(@csv_errors).to include('Invalid term "starting" in dt:dateCreatedPoint')
    end
    it 'reports invalid date point term for xlsx' do
      expect(@xlsx_errors).to include('Invalid term "starting" in dt:dateCreatedPoint')
    end
    it 'reports invalid date encoding term for csv' do
      expect(@csv_errors).to include('Invalid term "w3c" in dt:dateCreatedEncoding')
    end
    it 'reports invalid date encoding term for xlsx' do
      expect(@xlsx_errors).to include('Invalid term "w3c" in dt:dateCreatedEncoding')
    end
  end

  describe 'reports missing date point values:' do
    it 'reports missing date start point for csv' do
      expect(@csv_errors).to include('Possible date range missing dt:dateCreatedPoint')
    end
    it 'reports missing date start point for xlsx' do
      expect(@xlsx_errors).to include('Possible date range missing dt:dateCreatedPoint')
    end
    it 'reports missing date end point for csv' do
      expect(@csv_errors).to include('Possible date range missing dt:dateCreated2Point')
    end
    it 'reports missing date end point for xlsx' do
      expect(@xlsx_errors).to include('Possible date range missing dt:dateCreated2Point')
    end
  end

  describe 'reports unnecessary date attributes:' do
    it 'reports date key date without date value for csv' do
      expect(@csv_errors).to include('Unnecessary dt:dateCreatedKeyDate value for blank dt:dateCreated')
    end
    it 'reports date key date without date value for xlsx' do
      expect(@xlsx_errors).to include('Unnecessary dt:dateCreatedKeyDate value for blank dt:dateCreated')
    end
    it 'reports date encoding without date value for csv' do
      expect(@csv_errors).to include('Unnecessary dt:dateCreatedEncoding value for blank dt:dateCreated')
    end
    it 'reports date qualifier without date value for xlsx' do
      expect(@xlsx_errors).to include('Unnecessary dt:dateCreatedQualifier value for blank dt:dateCreated')
    end
    it 'reports date qualifier without date value for csv' do
      expect(@csv_errors).to include('Unnecessary dt:dateCreatedQualifier value for blank dt:dateCreated')
    end
    it 'reports date qualifier without date value for xlsx' do
      expect(@xlsx_errors).to include('Unnecessary dt:dateCreatedQualifier value for blank dt:dateCreated')
    end
    it 'reports date point without date value for csv' do
      expect(@csv_errors).to include('Unnecessary dt:dateCreatedPoint value for blank dt:dateCreated')
    end
    it 'reports date point without date value for xlsx' do
      expect(@xlsx_errors).to include('Unnecessary dt:dateCreatedPoint value for blank dt:dateCreated')
    end
  end

  describe 'reports invalid date encoding:' do
    it 'reports invalid w3cdtf encoding for csv' do
      expect(@csv_errors).to include('Date 1900-1-1 in dt:dateCreated does not match stated w3cdtf encoding')
    end
    it 'reports invalid w3cdtf encoding for xlsx' do
      expect(@xlsx_errors).to include('Date 2/2/1902 in dt:dateCreated2 does not match stated w3cdtf encoding')
    end
  end

  describe 'validates issuance:' do
    it 'reports invalid issuance term for csv' do
      expect(@csv_errors).to include('Invalid term "never" in or2:issuance')
    end
    it 'reports invalid issuance term for xlsx' do
      expect(@xlsx_errors).to include('Invalid term "never" in or2:issuance')
    end
  end

  # describe 'gets subject headers:'

  describe 'validates subject:' do
    it 'reports missing subject type for csv' do
      expect(@csv_errors).to include('Missing subject type in su1:p1:type')
    end
    it 'reports missing subject type for xlsx' do
      expect(@xlsx_errors).to include('Missing subject type in su1:p1:type')
    end
    it 'reports subject type without subject value for csv' do
      expect(@csv_errors).to include('Subject type provided but subject is empty in su1:p1:value')
    end
    it 'reports subject type without subject value for xlsx' do
      expect(@xlsx_errors).to include('Subject type provided but subject is empty in su1:p1:value')
    end
    it 'reports invalid subject type for csv' do
      expect(@csv_errors).to include('Invalid subject type "#NAME?" in su1:p1:type')
    end
    it 'reports invalid subject type for xlsx' do
      expect(@xlsx_errors).to include('Invalid subject type "#NAME?" in su1:p1:type')
    end
    it 'reports invalid subject name type for csv' do
      expect(@csv_errors).to include('Invalid subject name type "ineffable" in sn1:p1:nameType')
    end
    it 'reports invalid subject name type for xlsx' do
      expect(@xlsx_errors).to include('Invalid subject name type "ineffable" in sn1:p1:nameType')
    end
  end

  describe 'validates location:' do
    it 'reports missing purl for csv' do
      expect(@csv_errors).to include('Blank lo:purl')
    end
    it 'reports missing purl for xlsx' do
      expect(@xlsx_errors).to include('Blank lo:purl')
    end
  end

  describe 'logs errors:' do
    it 'logs fail error and exits for csv' do
      no_header_csv = Validator.new(@no_header_csv)
      no_header_csv.validate_headers
      expect(no_header_csv.errors).to include("FAIL" => [["FAIL", "Invalid header row, must begin with druid & sourceId (case-sensitive) and appear in first ten lines of file", "headers"]])
      expect(no_header_csv.report.closed?).to be(true)
    end
    it 'logs fail error and exits for xlsx' do
      no_header_xlsx = Validator.new(@no_header_xlsx)
      no_header_xlsx.validate_headers
      expect(no_header_xlsx.errors).to include("FAIL" => [["FAIL", "Invalid header row, must begin with druid & sourceId (case-sensitive) and appear in first ten lines of file", "headers"]])
      expect(no_header_xlsx.report.closed?).to be(true)
    end
    it 'logs non-fail error for csv' do
      expect(@csv.errors['ERROR']).to include(["ERROR", "Contains duplicate headers", "ge1:genre"])
    end
    it 'logs non-fail error for xlsx' do
      expect(@xlsx.errors['ERROR']).to include(["ERROR", "Contains duplicate headers", "ge1:genre"])
    end
    it 'logs warning for csv' do
      expect(@csv.errors['WARNING']).to include(["WARNING", "Blank ty1:typeOfResource", "aa111aa1111"])
    end
    it 'logs warning for xlsx' do
      expect(@xlsx.errors['WARNING']).to include(["WARNING", "Blank ty1:typeOfResource", "aa111aa1111"])
    end
    it 'logs info for csv' do
      expect(@csv.errors['INFO']).to include(["INFO", "Header not in XML template", "not:header"])
    end
    it 'logs info for xlsx' do
      expect(@xlsx.errors['INFO']).to include(["INFO", "Header not in XML template", "not:header"])
    end
    it 'logs the expected number of non-fail errors for csv' do
      expect(@csv.errors['ERROR'].size).to eq(26)
    end
    it 'logs the expected number of non-fail errors for xlsx' do
      expect(@xlsx.errors['ERROR'].size).to eq(26)
    end
    it 'logs the expected number of warnings for csv' do
      expect(@csv.errors['WARNING'].size).to eq(22)
    end
    it 'logs the expected number of warnings for xlsx' do
      expect(@xlsx.errors['WARNING'].size).to eq(23)
    end
    it 'logs the expected number of info for csv' do
      expect(@csv.errors['INFO'].size).to eq(5)
    end
    it 'logs the expected number of info for xlsx' do
      expect(@xlsx.errors['INFO'].size).to eq(10)
    end
  end

end
