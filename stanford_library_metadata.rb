require 'sucker_punch'
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
require './apps/transform_to_datacite_xml/lib/modsulator'
require './apps/transform_to_datacite_xml/app/models/modsulator_sheet'
require './apps/transform_to_datacite_xml/app/models/normalizer'
require './apps/authority_lookup/authority_lookup'
require './apps/authority_lookup/file_parser'
require './apps/authority_lookup/result_parser'
require './apps/compile_mods/compile_mods'
# require './apps/replayable_spreadsheet_generator/replayable_spreadsheet_generator'
require './jobs/authority_lookup_job'
require './jobs/compile_mods_job'
require './jobs/replayable_spreadsheet_validator_job'
require './jobs/reverse_modsulator_job'
require './jobs/transform_spreadsheet_job'
require './jobs/transform_to_datacite_xml_job'
require './jobs/virtual_object_manifest_job'
require './jobs/virtual_object_manifest_validate_job'

before do
  @authority_lookup_outfile = './public/authority_lookup/report.csv'
  @compile_mods_outfile = './public/compile_mods/compiled_mods_file.xml'
  @replayable_spreadsheet_validator_outfile = './public/replayable_spreadsheet_validator/report.csv'
  @reverse_modsulator_outfile = './public/reverse_modsulator/replayable_spreadsheet.csv'
  @reverse_modsulator_log_outfile = './public/reverse_modsulator/log.csv'
  @transform_spreadsheet_outfile = './public/transform_spreadsheet/replayable_spreadsheet.csv'
  @transform_to_datacite_outfile = './public/transform_to_datacite_xml/datacite_xml.zip'
  @transform_to_datacite_mods_template = './public/transform_to_datacite_xml/datacite_template_20200424.xlsx'
  @transform_to_datacite_only_template = './public/transform_to_datacite_xml/datacite_only_template_20200424.xlsx'
  @virtual_object_manifest_outfile = './public/virtual_object_manifest/manifest.csv'
  @virtual_object_manifest_log_outfile = './public/virtual_object_manifest/log.csv'
  @virtual_object_manifest_stats_outfile = './public/virtual_object_manifest/stats.csv'
end

get '/' do
  erb :index
end

get '/clear_cache' do
  clear_files('./public/compile_mods')
  clear_files('./public/replayable_spreadsheet_validator')
  clear_files('./public/reverse_modsulator')
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
  if processing_file?(@replayable_spreadsheet_validator_outfile, 'ValidatorJob') == true
    erb :processing
  else
    generate_report_table
    erb :replayable_spreadsheet_validator_download
  end
end

post '/replayable_spreadsheet_validator_deliver' do
  send_file(@replayable_spreadsheet_validator_outfile, :type => 'csv', :disposition => 'attachment')
end

def validate_rps
  ValidatorJob.perform_async(params[:file][:tempfile], @replayable_spreadsheet_validator_outfile)
end

def generate_report_table
  if File.zero?(@replayable_spreadsheet_validator_outfile)
    @validator_table = "No errors logged."
    @validator_download_display = ""
  else
    @validator_table = generate_html_table(@replayable_spreadsheet_validator_outfile)
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
  puts @transform_spreadsheet_outfile.inspect
  if processing_file?(@transform_spreadsheet_outfile, 'TransformerJob') == true
    erb :processing
  else
    erb :transform_spreadsheet_download
  end
end

post '/transform_spreadsheet_deliver' do
  puts @transform_spreadsheet_outfile.inspect
  send_file(@transform_spreadsheet_outfile, :type => 'csv', :disposition => 'attachment')
end

def transform_spreadsheet
  in_filename = params[:datafile][:tempfile].path
  map_filename = params[:mapfile][:tempfile].path
  TransformerJob.perform_async(in_filename, map_filename, @transform_spreadsheet_outfile)
end

##### Compile MODS for Argo upload #####

get '/compile_mods_index' do
  clear_files('./public/compile_mods')
  erb :compile_mods_index
end

post '/compile_mods_index' do
  clear_files('./public/compile_mods')
  erb :compile_mods_index
end

post '/compile_mods_process' do
  compile_mods
  redirect to('/compile_mods_download')
end

get '/compile_mods_download' do
  if processing_file?(@compile_mods_outfile, 'CompileMODSJob') == true
    erb :processing
  else
    erb :compile_mods_download
  end
end

post '/compile_mods_deliver' do
  send_file(@compile_mods_outfile, :type => 'xml', :disposition => 'attachment')
end

def compile_mods
  CompileMODSJob.perform_async(params[:file][:tempfile], @compile_mods_outfile)
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

post '/virtual_object_manifest_validate' do
  validate_virtual_object_manifest
  redirect to('/virtual_object_manifest_validate_download')
end

post '/virtual_object_manifest_process' do
  generate_virtual_object_manifest
  redirect to('/virtual_object_manifest_download')
end

get '/virtual_object_manifest_download' do
  if processing_file?(@virtual_object_manifest_log_outfile, 'ManifestGeneratorJob') == true
    erb :processing
  else
    generate_error_table
    generate_stats_table
    show_download
    erb :virtual_object_manifest_download
  end
end

get '/virtual_object_manifest_validate_download' do
  if processing_file?(@virtual_object_manifest_log_outfile, 'ManifestValidatorJob') == true
    erb :processing
  else
    generate_error_table
    erb :virtual_object_manifest_validate_download
  end
end

post '/virtual_object_manifest_deliver' do
  send_file(@virtual_object_manifest_outfile, :type => 'csv', :disposition => 'attachment')
end

def generate_virtual_object_manifest
  file = params[:file][:tempfile]
  ManifestGeneratorJob.perform_async(file, @virtual_object_manifest_outfile, @virtual_object_manifest_log_outfile, @virtual_object_manifest_stats_outfile)
end

def validate_virtual_object_manifest
  file = params[:file_validate][:tempfile]
  ManifestValidatorJob.perform_async(file, @virtual_object_manifest_log_outfile)
end

def generate_error_table
  if File.zero?(@virtual_object_manifest_log_outfile)
    @error_table = "No errors logged."
  else
    @error_table = generate_html_table(@virtual_object_manifest_log_outfile, has_headers=false)
  end
end

def generate_stats_table
  if !File.exist?(@virtual_object_manifest_stats_outfile) || File.zero?(@virtual_object_manifest_stats_outfile)
    @stats_table = "No data to display."
  else
    @stats_table = generate_html_table(@virtual_object_manifest_stats_outfile)
  end
end

def show_download
  if !File.exist?(@virtual_object_manifest_outfile) || File.zero?(@virtual_object_manifest_outfile)
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
  if processing_file?(@reverse_modsulator_outfile, 'ReverseModsulatorJob') == true
    erb :processing
  else
    if File.exist?(@reverse_modsulator_log_outfile) && !File.zero?(@reverse_modsulator_log_outfile)
      @rm_table = generate_html_table(@reverse_modsulator_log_outfile)
    else
      @rm_table = "No data loss reported."
    end
    erb :reverse_modsulator_download
  end
end

post '/reverse_modsulator_deliver' do
  send_file(@reverse_modsulator_outfile, :type => 'csv', :disposition => 'attachment')
end

def process_mods_file
  file = params[:file][:tempfile]
  ReverseModsulatorJob.perform_async(file, @reverse_modsulator_outfile, @reverse_modsulator_log_outfile)
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
  if processing_file?(@transform_to_datacite_outfile, 'DataCiteTransformerJob') == true
    erb :processing
  else
    erb :transform_to_datacite_xml_download
  end
end

post '/transform_to_datacite_xml_deliver' do
  send_file(@transform_to_datacite_outfile, :type => 'zip', :disposition => 'attachment')
end

post '/transform_to_datacite_xml_template' do
  send_file(@transform_to_datacite_mods_template, :type => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', :disposition => 'attachment')
end

post '/transform_to_datacite_xml_template_dc_only' do
  send_file(@transform_to_datacite_only_template, :type => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', :disposition => 'attachment')
end

def transform_to_datacite_xml
  in_file = params[:file][:tempfile]
  in_filename = params[:file][:tempfile].path
  DataCiteTransformerJob.perform_async(in_file, in_filename, @transform_to_datacite_outfile)
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
  if processing_file?(@authority_lookup_outfile, 'AuthorityLookupJob') == true
    erb :processing
  else
    erb :authority_lookup_download
  end
end

post '/authority_lookup_deliver' do
  send_file(@authority_lookup_outfile, :type => 'csv', :disposition => 'attachment')
end

def authority_lookup
  file = params[:file][:tempfile]
  subauthority = params[:subauthority]
  limit = params[:limit]
  AuthorityLookupJob.perform_async(file, subauthority, limit, @authority_lookup_outfile)
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

def processing_file?(outfile, job)
  if !File.exist?(outfile) || SuckerPunch::Queue.stats[job]['workers']['busy'] > 0
    return true
  else
    return false
  end
end
