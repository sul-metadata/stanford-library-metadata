require './apps/transform_spreadsheet/transform_spreadsheet'
require 'sucker_punch'

class TransformerJob
  include SuckerPunch::Job
  def perform(infile, mapfile, outfile)
    Transformer.new(infile, mapfile, outfile).transform
  end
end
