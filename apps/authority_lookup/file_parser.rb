class FileParser

  attr_reader :terms

  def initialize(file)
    if file.is_a? String
      @file = File.open(file)
    else
      @file = file
    end

    @terms = get_terms_from_file
  end

  def get_terms_from_file
    terms = []
    @file.each do |line|
      terms << line.strip
    end
    terms
  end

end
