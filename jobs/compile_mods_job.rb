require './apps/compile_mods/compile_mods'
require 'sucker_punch'

class CompileMODSJob
  include SuckerPunch::Job
  def perform(infile)
    filename = infile.path
    outfile = File.open('./public/compile_mods/compiled_mods_file.xml', 'w')
    MODSCompiler.new(infile, filename, outfile).process_input
  end
end
