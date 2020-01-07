require 'cgi'
require 'net/http'
require 'json'

class TermLookup

  attr_reader :result, :subauthority, :limit, :language

  def initialize(search_term, authority, base_url, subauthority: '', limit: 10, language: 'en')
    @search_term = search_term
    @authority = authority
    @base_url = base_url
    @exit = false

    @exit = true if @search_term == nil || @search_term == ""
    @exit = true if @authority == nil || @authority == ""
    @exit = true if @base_url == nil || @base_url == ""

    exit if @exit

    @subauthority = subauthority
    @limit = limit
    @language = language
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

  def lookup_term
    @result = {@search_term => []}
    @encoded_search_term = encode_search_term
    @query_url = construct_query
    @response = run_query
    parse_query_response
    return @result
  end

end
