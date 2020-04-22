require './apps/authority_lookup/authority_lookup'
require './apps/authority_lookup/file_parser'
require './apps/authority_lookup/response_parser'
require './apps/authority_lookup/result_parser'
require 'sucker_punch'

class AuthorityLookupJob
  include SuckerPunch::Job
  def perform(file, subauthority, limit, outfile)
    terms = FileParser.new(file).terms
    if subauthority.nil? || subauthority.empty? || ['geographic', 'conference'].include?(subauthority)
      result_set = AuthorityLookup.new(terms, "LOCNAMES_LD4L_CACHE", "https://lookup.ld4l.org/authorities/search/linked_data/", limit: limit.to_i, subauthority: subauthority).process_term_list
    elsif ['person', 'organization', 'family'].include?(subauthority)
      result_set = AuthorityLookup.new(terms, "LOCNAMES_RWO_LD4L_CACHE", "https://lookup.ld4l.org/authorities/search/linked_data/", limit: limit.to_i, subauthority: subauthority, parameter: "context=true").process_term_list
    end
    ResultParser.new(result_set, outfile)
  end
end
