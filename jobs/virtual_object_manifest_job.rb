require './apps/virtual_object_manifest/manifest_generator'
require './apps/virtual_object_manifest/manifest_sheet'

class ManifestGeneratorJob
  include SuckerPunch::Job
  def perform(file, outfile, log, stats)
    ManifestGenerator.new(file, outfile, log, stats).generate_manifest
  end
end
