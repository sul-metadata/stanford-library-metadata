require '../apps/compile_mods/compile_mods'
require './spec_helper'
require 'nokogiri'
require 'zip'

RSpec.describe MODSCompiler do

  describe 'process input:' do
    it 'processes a ZIP stream' do
      test = MODSCompiler.new(File.new("#{FIXTURES_DIR}/compile_mods/compile_mods_test.zip"), 'compile_mods_test.zip', File.join(PUBLIC_DIR, 'compile_mods/compiled_mods_file.xml'))
      test.process_input
      new_output = File.read(File.join(PUBLIC_DIR, 'compile_mods/compiled_mods_file.xml'))
      expected_output = File.read(File.join(FIXTURES_DIR, 'compile_mods/compile_mods_test.xml'))
      expect(new_output).to be_equivalent_to(expected_output).ignoring_attr_values('datetime', 'sourceFile')
    end

  end

end
