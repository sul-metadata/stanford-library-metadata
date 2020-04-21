require './apps/reverse_modsulator/mods_file'
require './apps/reverse_modsulator/reverse_modsulator'
require 'sucker_punch'

class ReverseModsulatorJob
  include SuckerPunch::Job
  def perform(infile, outfile, logfile)
    ReverseModsulator.new(infile, outfile, logfile, input: 'zip-stream')
  end
end
