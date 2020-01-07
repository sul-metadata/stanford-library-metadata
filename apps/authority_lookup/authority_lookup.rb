require_relative 'term_lookup'
require_relative 'result_parser'

class AuthorityLookup

  def initialize(term_list, authority, base_url, outfile, subauthority: '', limit: 10, language: 'en')
    @term_list = term_list
    @authority = authority
    @base_url = base_url
    @outfile = outfile
    @subauthority = subauthority
    @limit = limit
    @language = language

    @result_set = lookup_terms
    ResultParser.new(@result_set, @outfile)
  end

  def lookup_terms
    result_set = []
    @term_list.each do |term|
      result_set << TermLookup.new(term, @authority, @base_url, @subauthority, @limit, @language).result
    end
    result_set
  end


end
