require 'cgi'
require 'net/http'
require_relative 'response_parser'

class AuthorityLookup

  attr_reader :subauthority, :limit, :language, :parameter

  def initialize(term_list, authority, base_url, subauthority: '', limit: 10, language: '', parameter: '')
    @term_list = term_list
    @authority = authority
    @base_url = base_url
    @subauthority = subauthority
    @limit = limit
    @language = language
    @parameter = parameter

  end

  def process_term_list
    result_set = []
    @term_list.each do |search_term|
      next if search_term == nil || search_term.empty?
      result = lookup_term(search_term)
      result_set << result
    end
    result_set
  end

  def lookup_term(search_term)
    query_url = construct_query(search_term)
    response = run_query(query_url)
    parsed_response = parse_search_response(response, @authority)
    result = {search_term => parsed_response}
  end

  def encode_search_term(search_term)
    encoded_search_term = CGI::escape(search_term)
  end

  def construct_query(search_term)
    encoded_search_term = encode_search_term(search_term)
    query_url = "#{@base_url}#{@authority}"
    query_url += "/#{@subauthority}" unless @subauthority == nil || @subauthority.empty?
    query_url += "?q=#{encoded_search_term}&maxRecords=#{@limit}"
    query_url += "&lang=#{@language}" unless @language == nil || @language.empty?
    query_url += "&#{parameter}" unless @parameter == nil || @parameter.empty?
    query_url
  end

  def run_query(query_url)
    query = URI(query_url)
    Net::HTTP.get(query)
  end

   def parse_search_response(response, authority)
     parser = ResponseParser.new(response, authority)
     parser.parsed_response
   end

end
