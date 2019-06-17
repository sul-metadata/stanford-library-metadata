require 'csv'

class ResultParser

  def initialize(result_set, filename, fields=['label', 'uri'])
    @result_set = result_set
    @filename = filename
    @fields = fields
    @headers = @fields.unshift('search term')
    write_results_to_file
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
            @fields.each do |f|
              if match.keys.include?(f)
                row << match[f]
              else
                row << ""
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
