require 'cgi'
require 'net/http'
require 'json'

class AuthorityLookup

  attr_reader :subauthority, :limit, :language, :exit

  def initialize(term_list, authority, base_url, subauthority: '', limit: 10, language: '')
    @term_list = term_list
    @authority = authority
    @base_url = base_url
    @subauthority = subauthority
    @limit = limit
    @language = language
    @exit = false

    @exit = true if @term_list == nil || @term_list == []
    @exit = true if @authority == nil || @authority == ""
    @exit = true if @base_url == nil || @base_url == ""

    return if @exit

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
    encoded_search_term = encode_search_term(search_term)
    query_url = construct_query(encoded_search_term)
    # puts query_url.inspect
    response = run_query(query_url)
    parsed_response = JSON.parse(response)
    result = {search_term => parsed_response}
  end

  def encode_search_term(search_term)
    encoded_search_term = CGI::escape(search_term)
  end

  def construct_query(encoded_search_term)
    query_url = "#{@base_url}#{@authority}"
    query_url += "/#{@subauthority}" unless @subauthority == nil || @subauthority.empty?
    query_url += "?q=#{encoded_search_term}&maxRecords=#{@limit}"
    query_url += "&lang=#{@language}" unless @language == nil || @language.empty?
    query_url
  end

  def run_query(query_url)
    query = URI(query_url)
    Net::HTTP.get(query)
  end

end
