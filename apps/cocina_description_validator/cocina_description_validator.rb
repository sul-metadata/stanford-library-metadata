require 'json_schemer'
require 'csv'

class CocinaValidator

attr_reader :data, :validator, :outfile, :result

  def initialize(data, outfile)
    @data = data
    @outfile = outfile
    @csv = CSV.new(File.open(@outfile, 'w'))
    @schema_file = File.expand_path('./description_cocina_schema_v4-6_validator.json', File.dirname(__FILE__))
    @validator = parse_schema
  end

  def parse_schema
    JSONSchemer.schema(File.read(@schema_file))
  end

  def identify_errors
    @validator.validate(@data).to_a
  end

  def format_error(error)
    data_pointer, type, schema = error.values_at('data_pointer', 'type', 'schema')
    location = data_pointer.empty? ? 'root' : "property '#{data_pointer}'"
    case type
    when 'required'
      keys = error.fetch('details').fetch('missing_keys').join(', ')
      ["One or more required properties are missing: #{keys}", location]
    when 'null', 'string', 'boolean', 'integer', 'number', 'array', 'object'
      ["Value must be of type #{type}", location]
    when 'pattern'
      ["Value must match pattern: #{schema.fetch('pattern')}", location]
    when 'format'
      ["Value must have format #{schema.fetch('format')}", location]
    when 'const'
      ["Value must equal #{schema.fetch('const').inspect}", location]
    when 'enum'
      ["Value must be in list #{schema.fetch('enum')}", location]
    else
      ["Property is invalid", location]
    end
  end

  def report_errors(errors)
    @csv << ["Description", "Locator"]
    errors.each do |error|
      @csv << format_error(error)
    end
    @csv.close
  end

  def validate_data
    @result = @validator.valid?(@data)
    return true if @result == true
    @result = false
    errors = identify_errors
    report_errors(errors)
  end

end
