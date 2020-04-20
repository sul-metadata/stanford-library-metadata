require './apps/compile_mods/compile_mods'
require 'sucker_punch'

class CompileMODSJob
  include SuckerPunch::Job
  def perform(infile, outfile)
    filename = infile.path
    outfile_obj = File.open(outfile, 'w')
    MODSCompiler.new(infile, filename, outfile).process_input
  end
end
