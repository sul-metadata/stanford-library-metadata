require './apps/virtual_object_manifest/manifest_generator'
require './apps/virtual_object_manifest/manifest_sheet'

class ManifestValidatorJob
  include SuckerPunch::Job
  def perform(file, log)
    validator = ManifestSheet.new(file, log)
    validator.validate
    validator.write_error_output
  end
end
