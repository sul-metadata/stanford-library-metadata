class TemplateParser

  def initialize(template_filename)
    @template_filename = template_filename
  end

  # Get ordered array of header codes from the template.
  # @return [Array]             Ordered list of header codes appearing in the template.
  def get_template_headers
    template_headers = File.read(@template_filename).scan(/\[\[([A-Za-z0-9:]+)\]\]/).uniq.flatten
  end

end
