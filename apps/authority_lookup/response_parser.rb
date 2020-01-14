require 'json'

class ResponseParser

  attr_reader :result

  def initialize(response, authority)
    @response = response
    @authority = authority
    @result = []
  end

  def parse_response

    if @authority == 'LOCNAMES_RWO_LD4L_CACHE'
      parser = LOCNAMES_RWO_LD4L_CACHE.new(@response)
      parser.parse_response
      @result = parser.result
    end

  end

end

class LOCNAMES_RWO_LD4L_CACHE < ResponseParser

  attr_reader :result

  def initialize(response)
    @response = response
    @result = []
  end

  def parse_response
    parsed_json = JSON.parse(@response)
    parsed_json.each do |match|
      label = match['label']
      uri = match["context"].select { |item| item["property"] == "Authority URI" }.first["values"].first
      @result << {'label' => label, 'uri' => uri}
    end
  end

end
