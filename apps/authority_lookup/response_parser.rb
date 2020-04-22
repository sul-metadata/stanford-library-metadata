require 'json'

class ResponseParser

  attr_reader :parsed_response

  def initialize(response, authority)
    @response = response
    @authority = authority
    @parsed_response = []

    parse_response
  end

  def parse_response

    if @authority == 'LOCNAMES_LD4L_CACHE'
      @parsed_response = parse_response_LOCNAMES_LD4L_CACHE
    elsif @authority == 'LOCNAMES_RWO_LD4L_CACHE'
      @parsed_response = parse_response_LOCNAMES_RWO_LD4L_CACHE
    end

  end

  def parse_response_LOCNAMES_LD4L_CACHE
    result = []
    parsed_json = JSON.parse(@response)
    parsed_json.each do |match|
      label = match['label']
      uri = match['uri']
      result << {'label' => label, 'uri' => uri}
    end
    result
  end

  def parse_response_LOCNAMES_RWO_LD4L_CACHE
    result = []
    parsed_json = JSON.parse(@response)
    parsed_json.each do |match|
      label = match['label']
      uri = match["context"].select { |item| item["property"] == "Authority URI" }.first["values"].first
      result << {'label' => label, 'uri' => uri}
    end
    result
  end

end
