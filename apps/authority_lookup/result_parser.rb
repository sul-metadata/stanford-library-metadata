require 'csv'

class ResultParser

  def initialize(result_set, filename)
    @result_set = result_set
    @filename = filename
    @headers = get_headers
    write_results_to_file
  end

  def get_headers
    @fields = []
    @result_set.each do |match_query|
      match_query.each do |term, matches|
        next if matches.empty?
        @fields = matches.first.keys.sort
        break
      end
    end
    headers = ['search term', @fields].flatten
  end

  def write_results_to_file
    outfile = CSV.new(File.open(@filename, 'w'))
    outfile << @headers
    @result_set.each do |match_query|
      match_query.each do |term, matches|
        if matches.empty?
          row = [term, 'no results']
          outfile << row
        else
          matches.each do |match|
            row = [term]
            if match.class == Array
              row << "lookup error"
            else
              @fields.each do |f|
                if match.keys.include?(f)
                  row << match[f]
                else
                  row << ""
                end
              end
            end
            outfile << row
          end
        end
      end
    end
    outfile.close
  end

end
