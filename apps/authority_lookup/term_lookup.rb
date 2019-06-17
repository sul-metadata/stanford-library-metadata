require 'cgi'
require 'net/http'
require 'json'

class TermLookup

  attr_reader :result

  def initialize(search_term, authority, base_url, options = {})
    @search_term = search_term
    @authority = authority
    @base_url = base_url

    exit if @search_term == nil || @search_term == ""
    exit if @authority == nil || @authority == ""
    exit if @base_url == nil || @base_url == ""

    if options[:subauthority] == nil
      @subauthority = ""
    else
      @subauthority = options[:subauthority]
    end

    if options[:limit] == nil
      @limit = 10
    else
      @limit = options[:limit]
    end

    if options[:language] == nil
      @language = 'en'
    else
      @language = options[:language]
    end

    @result = {@search_term => []}
    @encoded_search_term = encode_search_term
    @query_url = construct_query
    @response = run_query
    parse_query_response
    return @result
  end

  def encode_search_term
    encoded_search_term = CGI::escape(@search_term)
  end

  def construct_query
    query_url = "#{@base_url}#{@authority}"
    query_url += "/#{@subauthority}" if @subauthority != ""
    query_url += "?q=#{@encoded_search_term}&maxRecords=#{@limit}&lang=#{@language}"
  end

  def run_query
    query = URI(@query_url)
    Net::HTTP.get(query)
  end

  def parse_query_response
    parsed_response = JSON.parse(@response)
    parsed_response.each do |r|
      @result[@search_term] << r
    end
  end

end
