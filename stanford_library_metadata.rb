require 'sinatra'
require 'csv'
require 'roo'
require 'active_support/core_ext/hash'
require 'erb'
require 'zip'
require 'cgi'
require 'net/http'
require 'json'
require './apps/replayable_spreadsheet_validator/replayable_spreadsheet_validator'
require './apps/transform_spreadsheet/transform_spreadsheet'
require './apps/virtual_object_manifest/manifest_generator'
require './apps/reverse_modsulator/reverse_modsulator'
require './apps/transform_to_datacite/lib/modsulator'
require './apps/transform_to_datacite/app/models/modsulator_sheet'
require './apps/transform_to_datacite/app/models/normalizer'
require './apps/authority_lookup/authority_lookup'
require './apps/authority_lookup/file_parser'
require './apps/authority_lookup/result_parser'
# require './apps/replayable_spreadsheet_generator/replayable_spreadsheet_generator'


get '/' do
  erb :index
end

get '/clear_cache' do
  clear_files('./public/reverse_modsulator')
  clear_files('./public/replayable_spreadsheet_validator')
  clear_files('./public/transform_spreadsheet')
  clear_files('./public/virtual_object_manifest')
end

##### Replayable spreadsheet validator

get '/replayable_spreadsheet_validator_index' do
  clear_files('./public/replayable_spreadsheet_validator')
  erb :replayable_spreadsheet_validator_index
end

post '/replayable_spreadsheet_validator_index' do
  clear_files('./public/replayable_spreadsheet_validator')
  erb :replayable_spreadsheet_validator_index
end

post '/replayable_spreadsheet_validator_process' do
  validate_rps
  redirect to('/replayable_spreadsheet_validator_download')
end

get '/replayable_spreadsheet_validator_download' do
  generate_report_table
  erb :replayable_spreadsheet_validator_download
end

post '/replayable_spreadsheet_validator_deliver' do
  send_file('./public/replayable_spreadsheet_validator/report.csv', :type => 'csv', :disposition => 'attachment')
end

def validate_rps
  filename = params[:file][:tempfile].path
  result = Validator.new(filename).validate_spreadsheet
end

def generate_report_table
  if File.zero?('./public/replayable_spreadsheet_validator/report.csv')
    @validator_table = "No errors logged."
    @validator_download_display = ""
  else
    @validator_table = generate_html_table('./public/replayable_spreadsheet_validator/report.csv')
    @validator_download_display = generate_download_button("/replayable_spreadsheet_validator_deliver", "post", "Download report")
  end
end

##### Transform spreadsheet to replayable spreadsheet

get '/transform_spreadsheet_index' do
  clear_files('./public/transform_spreadsheet')
  erb :transform_spreadsheet_index
end

post '/transform_spreadsheet_index' do
  clear_files('./public/transform_spreadsheet')
  erb :transform_spreadsheet_index
end

post '/transform_spreadsheet_process' do
  transform_spreadsheet
  redirect to('/transform_spreadsheet_download')
end

get '/transform_spreadsheet_download' do
  erb :transform_spreadsheet_download
end

post '/transform_spreadsheet_deliver' do
  send_file('./public/transform_spreadsheet/replayable_spreadsheet.csv', :type => 'csv', :disposition => 'attachment')
end

def transform_spreadsheet
  in_filename = params[:datafile][:tempfile].path
  map_filename = params[:mapfile][:tempfile].path
  Transformer.new(in_filename, map_filename, './public/transform_spreadsheet/replayable_spreadsheet.csv').transform
end

##### Virtual object manifest

get '/virtual_object_manifest_index' do
  clear_files('./public/virtual_object_manifest')
  erb :virtual_object_manifest_index
end

post '/virtual_object_manifest_index' do
  clear_files('./public/virtual_object_manifest')
  erb :virtual_object_manifest_index
end

post '/virtual_object_manifest_process' do
  generate_virtual_object_manifest
  redirect to('/virtual_object_manifest_download')
end

get '/virtual_object_manifest_download' do
  generate_error_table
  generate_stats_table
  show_download
  erb :virtual_object_manifest_download
end

post '/virtual_object_manifest_download' do
  generate_error_table
  generate_stats_table
  show_download
  erb :virtual_object_manifest_download
end

post '/virtual_object_manifest_deliver' do
  send_file('./public/virtual_object_manifest/manifest.csv', :type => 'csv', :disposition => 'attachment')
end

def generate_virtual_object_manifest
  file = params[:file][:tempfile]
  ManifestGenerator.new(file).generate_manifest
end

def generate_error_table
  if File.zero?('./public/virtual_object_manifest/errors.csv')
    @error_table = "No errors logged."
  else
    @error_table = generate_html_table('./public/virtual_object_manifest/errors.csv', has_headers=false)
  end
end

def generate_stats_table
  if !File.exist?('./public/virtual_object_manifest/stats.csv') || File.zero?('./public/virtual_object_manifest/stats.csv')
    @stats_table = "No data to display."
  else
    @stats_table = generate_html_table('./public/virtual_object_manifest/stats.csv')
  end
end

def show_download
  if !File.exist?('./public/virtual_object_manifest/manifest.csv') || File.zero?('./public/virtual_object_manifest/manifest.csv')
    @manifest_download_display = "Manifest not created due to errors."
  else
    @manifest_download_display = generate_download_button("/virtual_object_manifest_deliver", "post", "Download manifest")
  end
end


##### Reverse modsulator

get '/reverse_modsulator_index' do
  clear_files('./public/reverse_modsulator')
  erb :reverse_modsulator_index
end

post '/reverse_modsulator_index' do
  clear_files('./public/reverse_modsulator')
  erb :reverse_modsulator_index
end

post '/reverse_modsulator_process' do
  process_mods_file
  redirect to('/reverse_modsulator_download')
end

get '/reverse_modsulator_download' do
  if File.exist?('./public/reverse_modsulator/log.csv') && !File.zero?('./public/reverse_modsulator/log.csv')
    @rm_table = generate_html_table('./public/reverse_modsulator/log.csv')
  else
    @rm_table = "No data loss reported."
  end
  erb :reverse_modsulator_download
end

post '/reverse_modsulator_deliver' do
  send_file('./public/reverse_modsulator/replayable_spreadsheet.csv', :type => 'csv', :disposition => 'attachment')
end

def process_mods_file
  file = params[:file][:tempfile]
  ReverseModsulator.new(file, "./public/reverse_modsulator/replayable_spreadsheet.csv", input: 'zip-stream')
end



##### Transform to DataCite

get '/transform_to_datacite_xml_index' do
  clear_files('./public/transform_to_datacite_xml')
  erb :transform_to_datacite_xml_index
end

post '/transform_to_datacite_xml_index' do
  clear_files('./public/transform_to_datacite_xml')
  erb :transform_to_datacite_xml_index
end

post '/transform_to_datacite_xml_process' do
  transform_to_datacite_xml
  redirect to('/transform_to_datacite_xml_download')
end

get '/transform_to_datacite_xml_download' do
  erb :transform_to_datacite_xml_download
end

post '/transform_to_datacite_xml_deliver' do
  send_file('./public/transform_to_datacite_xml/datacite_xml.zip', :type => 'zip', :disposition => 'attachment')
end

post '/transform_to_datacite_xml_template' do
  send_file('./public/transform_to_datacite_xml/datacite_template_20200110.xlsx', :type => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', :disposition => 'attachment')
end

post '/transform_to_datacite_xml_template_dc_only' do
  send_file('./public/transform_to_datacite_xml/datacite_only_template_20190626.xlsx', :type => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', :disposition => 'attachment')
end

def transform_to_datacite_xml
  in_file = params[:file][:tempfile]
  in_filename = params[:file][:tempfile].path
  xml = Modsulator.new(in_file, in_filename).convert_rows
  doc = Nokogiri::XML(xml)
  records = doc.xpath('//*[local-name()="resource"]')
  xml_declaration = '<?xml version="1.0" encoding="UTF-8"?>'
  Zip::File.open('./public/transform_to_datacite_xml/datacite_xml.zip', Zip::File::CREATE) do |z|
    records.each do |resource|
      druid = resource.parent['objectId']
      z.get_output_stream("#{druid}.xml") {|f| f.puts "#{xml_declaration}\n#{resource.to_s}"}
    end
  end
end


##### Authority lookup

get '/authority_lookup_index' do
  clear_files('./public/authority_lookup')
  erb :authority_lookup_index
end

post '/authority_lookup_index' do
  clear_files('./public/authority_lookup')
  erb :authority_lookup_index
end

post '/authority_lookup_process' do
  authority_lookup
  redirect to('/authority_lookup_download')
end

get '/authority_lookup_download' do
  erb :authority_lookup_download
end

post '/authority_lookup_deliver' do
  send_file('./public/authority_lookup/report.csv', :type => 'csv', :disposition => 'attachment')
end

def authority_lookup
  file = params[:file][:tempfile]
  subauthority = params[:subauthority]
  limit = params[:limit]
  terms = FileParser.new(file).terms
  result_set = AuthorityLookup.new(terms, "LOCNAMES_LD4L_CACHE", "https://lookup.ld4l.org/authorities/search/linked_data/", limit: limit.to_i, subauthority: subauthority).process_term_list
  ResultParser.new(result_set, './public/authority_lookup/report.csv')
end


#####

# get '/replayable_spreadsheet_generator_index' do
#   clear_files('./public/replayable_spreadsheet_generator')
#   erb :replayable_spreadsheet_generator_index
# end
#
# post '/replayable_spreadsheet_generator_index' do
#   clear_files('./public/replayable_spreadsheet_generator')
#   erb :replayable_spreadsheet_generator_index
# end
#
# post '/replayable_spreadsheet_generator_process' do
#   replayable_spreadsheet_generator
#   redirect to('/replayable_spreadsheet_generator_download')
# end
#
# get '/replayable_spreadsheet_generator_download' do
#   erb:replayable_spreadsheet_generator_download
# end
#
# post '/replayable_spreadsheet_generator_deliver' do
#   send_file('./public/replayable_spreadsheet_generator/replayable_spreadsheet_headers.csv', :type => 'csv', :disposition => 'attachment')
# end
#
# def replayable_spreadsheet_generator
#   ReplayableSpreadsheetGenerator.new('./public/replayable_spreadsheet_generator/params.txt', './public/replayable_spreadsheet_generator/replayable_spreadsheet_headers.csv')
# end

#####

def clear_files(path)
  Dir.foreach(path) do |f|
    next unless f.end_with?('.csv', '.txt', '.zip')
    File.delete("#{path}/#{f}")
  end
end

def generate_html_table(file, has_headers=true)
  csv = CSV.new(File.open(file))
  rows = csv.read
  table = "<table><tr>"
  if has_headers
    headers = rows.shift
    headers.each { |header| table << "<th>#{header}</th>"}
  else
    column_count = rows[0].size
    table << "<th>.</th>" * column_count
  end
  table << "</tr>"
  rows.each do |row|
    table << "<tr>"
    row.each do |value|
      table << "<td>#{value}</td>"
    end
    table << "</tr>"
  end
  table << "</table>"
end

def generate_download_button(action, method, label)
  "<form action=\"#{action}\" method=\"#{method}\"> <button class=\"button\" type=\"submit\">#{label}</button> </form>"
end
