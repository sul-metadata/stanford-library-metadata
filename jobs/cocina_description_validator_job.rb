require './apps/cocina_description_validator/cocina_description_validator'
require 'sucker_punch'

class CocinaValidatorJob
  include SuckerPunch::Job
  def perform(data, outfile)
    result = CocinaValidator.new(data, outfile).validate_data
  end
end
