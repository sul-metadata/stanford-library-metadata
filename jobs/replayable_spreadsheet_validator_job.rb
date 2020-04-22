require './apps/replayable_spreadsheet_validator/replayable_spreadsheet_validator'
require 'sucker_punch'

class ValidatorJob
  include SuckerPunch::Job
  def perform(infile, outfile)
    filename = infile.path
    result = Validator.new(filename, outfile).validate_spreadsheet
  end
end
