require 'roo'

class Validator

  def initialize(filename)
    @filename = filename
    @template = './apps/replayable_spreadsheet_validator/modsulator_template.xml'
    @extension = File.extname(@filename)

    @exit = false

    ## Error data collection

    # Error type labels for output
    @fail = "FAIL"
    @error = "ERROR"
    @warning = "WARNING"
    @info = "INFO"

    @errors = {
      @fail => [],
      @error => [],
      @warning => [],
      @info => []
    }

    ## Term lists

    # typeOfResource / tyX:typeOfResource
    @type_of_resource_terms = [
      'text',
      'cartographic',
      'notated music',
      'sound recording',
      'sound recording-musical',
      'sound recording-nonmusical',
      'still image',
      'moving image',
      'three dimensional object',
      'software, multimedia',
      'mixed material'
    ]

    # subject / suX:pX:value
    @subject_subelements = [
      'topic',
      'geographic',
      'temporal',
      'genre'
    ]

    # titleInfo type / tiX:type
    @title_type_terms = [
      'alternative',
      'abbreviated',
      'translated',
      'uniform'
    ]

    # name type / naX:type
    @name_type_terms = [
      'conference',
      'corporate',
      'family',
      'personal'
    ]

    # Date subelements of originInfo in replayable spreadsheet / dt:*
    # Other MODS date subelements not included: dateValid, dateModified
    @date_elements = [
      'dateCreated',
      'dateIssued',
      'dateCaptured',
      'copyrightDate',
      'dateOther'
    ]

    # originInfo/date* qualifier / dt:*Qualifier
    @date_qualifier_terms = [
      'approximate',
      'inferred',
      'questionable'
    ]

    # originInfo/date* point / dt:*Point
    @date_point_terms = [
      'start',
      'end'
    ]

    # Date encodings allowed in MODS
    # originInfo/date* encoding / dt:*Encoding
    @date_encoding_terms = [
      'w3cdtf',
      'iso8601',
      'marc',
      'edtf',
      'temper'
    ]

    # originInfo/issuance
    @issuance_terms = [
      'continuing',
      'monographic',
      'single unit',
      'multipart monograph',
      'serial',
      'integrating resource'
    ]

    # For attributes whose only valid value is "yes"
    @yes_terms = [
      'yes'
    ]

    # Spreadsheet value errors
    @cell_errors = [
      '#N/A',
      '#REF!',
      '#NAME?',
      '#VALUE?',
      '0'
    ]

  end


  def validate_spreadsheet
    # Check for allowed file extensions and fail if invalid
    validate_file_extension
    return true if @exit == true
    validate_file_encoding
    return true if @exit == true
    validate_file_open
    validate_headers
    return true if @exit == true
    validate_rows
    validate_druid
    validate_sourceid
    validate_title
    validate_name
    validate_type_of_resource
    validate_date_and_origin_info
    validate_subject
    validate_location
    report_errors
  end

  def validate_file_extension
    unless ['.csv', '.xls', '.xlsx'].include?(@extension)
      log_error(@fail, "Invalid input file extension #{@extension}: use .csv, .xls, or .xlsx", "filename")
      @exit = true
    end
  end

  def validate_file_encoding
    # Check if file has acceptable encoding (UTF-8 or ASCII, non-binary/CSV only)
    enc_data = `file -i "#{@filename}"`
    encoding = enc_data.match(/charset=.*$/)[0]
    return if encoding.strip == 'charset=binary'
    unless encoding.strip == 'charset=utf-8' || encoding.strip == 'charset=us-ascii'
      log_error(@fail, "file", "Invalid encoding: File #{encoding} instead of UTF-8 or ASCII")
      @exit = true
    end
  end

  def validate_file_open
    # Check if modsulator can open file
    @xlsx = nil
    begin
      if @extension == '.xlsx'
        @xlsx = Roo::Excelx.new(@filename)
      else
        CSV.foreach(@filename) do |row|
          break
        end
      end
    rescue
      log_error(@fail, "file", "Could not open file, check for bad character encoding")
      @exit = true
      return
    end
  end

  def validate_headers
    # Try to identify header row by first two values and fail if not identified
    @header_row = []
    i = 0
    if @extension == '.csv'
      CSV.foreach(@filename) do |row|
        if [row[0], row[1]] == ['druid', 'sourceId']
          @header_row = row
          @header_row_index = i
          break
        elsif i == 9
          log_error(@fail, "headers", "Invalid header row, must begin with druid & sourceId (case-sensitive) and appear in first ten lines of file")
          @exit = true
          return
        else
          i += 1
        end
      end
    else
      i = 0
      @xlsx.each_row_streaming(pad_cells: true, max_rows: 10) do |row|
        if [row[0], row[1]] == ['druid', 'sourceId']
          @header_row = row
          @header_row_index = i
          break
        elsif i == 9
          log_error(@fail, "headers", "Invalid header row, must begin with druid & sourceId (case-sensitive) and appear in first ten lines of file")
          @exit = true
          return
        else
          i += 1
        end
      end
    end
    @header_row_terms = @header_row.compact

    # Report duplicate header codes
    if has_duplicates?(@header_row_terms)
      log_error(@error, get_duplicates(@header_row_terms), "Contains duplicate headers")
    end

    # Report spreadsheet headers that do not appear in current template
    xml_template_headers = []
    File.open(@template, 'rb') {|f| xml_template_headers << f.read.scan(/\[.*?\]\]/) }
    xml_template_headers.flatten!
    xml_template_headers.map! {|x| x.slice(2..-3)}
    headers_not_in_template = @header_row_terms - xml_template_headers - ["druid", "sourceId"]
    if headers_not_in_template != []
      log_error(@info, headers_not_in_template.uniq.join(", "), "Header not in XML template")
    end

    # Report absence of title columns
    unless @header_row_terms.any? {|h| h.match(/^ti\d+:title$/)}
      log_error(@error, "ti1:title", "Missing required column")
    end

    # Report absence of type of resource column
    unless @header_row_terms.include?('ty1:typeOfResource')
      log_error(@warning, "ty1:typeOfResource", "Recommended column missing")
    end

  end

  def validate_rows
    # Report blank rows, control characters, open quotation marks, and cell errors
    @selected_headers = {
      'title_type' => select_by_pattern(@header_row_terms, /^ti\d+:type$/),
      'name_type' => select_by_pattern(@header_row_terms, /^na\d+:type$/),
      'type_of_resource' => select_by_pattern(@header_row_terms, /^ty\d+:/) - ["ty1:manuscript"],
      'dates' => get_date_headers(),
      'issuance' => select_by_pattern(@header_row_terms, 'issuance')
    }
    @blank_row_index = []
    @spreadsheet.each_with_index do |row, i|
      if row.compact.join("").match(/^\s*$/)
        log_error(@error, "row #{i+1}", "Blank row")
        @blank_row_index << i
      else
        row.each_with_index do |cell, j|
          next if cell == nil || cell.class != String
          cell_ref = "#{get_column_ref(j)}#{i+1}"
          if cell.match(/[\r\n]+/)
            log_error(@error, cell_ref, "Line break in cell text")
          elsif cell.match(/[\u0000-\u001F]/)
            log_error(@error, cell_ref, "Control character in cell text")
          end
          if cell.match(/^["“”][^"]*/)
            log_error(@warning, cell_ref, "Cell value begins with unclosed double quotation mark")
          end
          case cell
          when '#N/A'
            na_error << cell_ref
          when '#REF!'
            ref_error << cell_ref
          when '0'
            zero_error << cell_ref
          when '#NAME?'
            name_error << cell_ref
          when '#VALUE?'
            value_error << cell_ref
          end
        end
      end
    end
    unless na_error.empty?
      log_error(@error, na_error.join(", "), "#N/A error in cell")
    end
    unless ref_error.empty?
      log_error(@error, ref_error.join(", "), "#REF! error in cell")
    end
    unless zero_error.empty?
      log_error(@warning, zero_error.join(", "), "Cell value is 0")
    end
    unless name_error.empty?
      log_error(@error, name_error.join(", "), "#NAME? error in cell")
    end
    unless value_error.empty?
      log_error(@error, value_error.join(", "), "#VALUE? error in cell")
    end
  end

  def validate_druid
    # Get druids from first column
    @druids = @spreadsheet.column(1)

    # Report duplicate druids
    if has_duplicates?(@druids)
      log_error(@error, get_duplicates(@druids), "Duplicate druids")
    end

    # Report missing and invalid values in druid column
    @druids.each_with_index do |druid, i|
      next if i <= @header_row_index
      if value_is_blank_in_nonblank_row?(druid, i)
        log_error(@error, "row #{i+1}", "Blank druid")
      elsif !value_is_blank?(druid) && !druid.strip.match(/^[a-z][a-z][0-9][0-9][0-9][a-z][a-z][0-9][0-9][0-9][0-9]$/)
        log_error(@error, druid, "Invalid druid")
      end
    end
  end

  def validate_sourceid
    # Get source IDs from second column
    source_ids = @spreadsheet.column(2)

    # Report duplicate source IDs
    if has_duplicates?(source_ids.compact)
      log_error(@info, get_duplicates(source_ids), "Duplicate source IDs")
    end

    # Report empty cells in source ID column
    source_ids.each_with_index do |source_id, i|
      next if i <= @header_row_index
      if value_is_blank_in_nonblank_row?(source_id, i)
        log_error(@info, get_druid_or_row_number(i), "Blank source ID")
      end
    end
  end

  def validate_title
    # Report missing title in first title column
     if @header_row_terms.include?("ti1:title")
      report_blank_values_by_header("ti1:title", @error)
    end

    # Report invalid title type
    title_type_headers = select_by_pattern(@header_row_terms, /^ti\d+:type$/)
    title_type_headers.each do |h|
      report_invalid_values_by_header(h, @title_type_terms)
    end
  end

  def validate_name
    # Report invalid name type
    name_type_headers = select_by_pattern(@header_row_terms, /^na\d+:type$/)
    name_type_headers.each do |h|
      report_invalid_values_by_header(h, @name_type_terms)
    end

    # Report invalid usage value ("primary" is only value allowed)
    report_invalid_values_by_header('na1:usage', ['primary'])
  end

  def validate_type_of_resource
    # Report missing (required) or invalid type of resource value
    type_of_resource_headers = select_by_pattern(@header_row_terms, /^ty\d+:/)
    type_of_resource_headers.delete("ty1:manuscript")
    if type_of_resource_headers.size == 0
      log_error(@warning, "ty1:typeOfResource", "Recommended column missing")
    else
      type_of_resource_headers.each do |h|
        if h == "ty1:typeOfResource"
          report_blank_values_by_header(h, @warning)
        end
        report_invalid_values_by_header(h, @type_of_resource_terms)
      end
    end

    # Report invalid values in ty1:manuscript
    report_invalid_values_by_header('ty1:manuscript', @yes_terms)
  end

  def validate_date_and_origin_info
    # Get date headers present in spreadsheet and group by prefix(es)
    all_date_headers = collect_by_pattern(@header_row_terms, /^(o?r?[23]?:?dt\d?:)/)
    key_dates = {}
    # Iterate over the set of headers for each prefix
    all_date_headers.each do |prefix, originInfo_instance_headers|
      # Iterate over the set of date headers for each date type (dateCreated, etc.)
      @date_elements.each do |date_group_term|
        # Get date headers actually in spreadsheet for this group
        date_group_headers = select_by_pattern(originInfo_instance_headers, /#{date_group_term}/)
        # Skip to next if date type for this iteration is not in spreadsheet
        next if value_is_blank?(date_group_headers)
        # Base of date term (dateCreated, etc.) and suffixes for date headers (keyDate, etc.)
        date_base, date1, key_date, encoding, date1_qualifier, date1_point, date2, date2_qualifier, date2_point, date3, date3_key_date, date3_encoding, date3_qualifier = Array.new(13, [])
        # Identify values under each possible header for given date type if header is present
        current_headers = {}
        date_group_headers.each do |h|
          date_base = "#{prefix}#{date_group_term}"
          # Single date or start of range (dateCreated, etc.)
          if h == date_base
            date1 = get_values_by_header(h)
            current_headers['date1'] = h
          else
            # Get values by header suffix
            h_uniq = h.gsub(date_base,"")
            case h_uniq
            when "KeyDate"
              key_date = get_values_by_header(h)
              current_headers['key_date'] = h
            when "Encoding"
              encoding = get_values_by_header(h)
              current_headers['encoding'] = h
            when "Qualifier"
              date1_qualifier = get_values_by_header(h)
              current_headers['date1_qualifier'] = h
             when "Point"
              date1_point = get_values_by_header(h)
              current_headers['date1_point'] = h
            when "2"
              date2 = get_values_by_header(h)
              current_headers['date2'] = h
            when "2Qualifier"
              date2_qualifier = get_values_by_header(h)
              current_headers['date2_qualifier'] = h
            when "2Point"
              date2_point = get_values_by_header(h)
              current_headers['date2_point'] = h
            when "3"
              date3 = get_values_by_header(h)
              current_headers['date3'] = h
            when "3KeyDate"
              date3_key_date = get_values_by_header(h)
              current_headers['date3_key_date'] = h
            when "3Encoding"
              date3_encoding = get_values_by_header(h)
              current_headers['date3_encoding'] = h
            when "3Qualifier"
              date3_qualifier = get_values_by_header(h)
              current_headers['date3_qualifier'] = h
            end
          end
        end

        # Report invalid values for each field in this date type
        date1.each_index do |i|
          next if i <= @header_row_index
          id = get_druid_or_row_number(i)
          report_invalid_value(key_date[i], @yes_terms, id, current_headers['key_date'])
          report_invalid_value(date3_key_date[i], @yes_terms, id, current_headers['date3_key_date'])
          report_invalid_value(date1_qualifier[i], @date_qualifier_terms, id, current_headers['date1_qualifier'])
          report_invalid_value(date2_qualifier[i], @date_qualifier_terms, id, current_headers['date2_qualifier'])
          report_invalid_value(date3_qualifier[i], @date_qualifier_terms, id, current_headers['date3_qualifier'])
          report_invalid_value(date1_point[i], @date_point_terms, id, current_headers['date1_point'])
          report_invalid_value(date2_point[i], @date_point_terms, id, current_headers['date2_point'])
          report_invalid_value(encoding[i], @date_encoding_terms, id, current_headers['encoding'])
          report_invalid_value(date3_encoding[i], @date_encoding_terms, id, current_headers['date3_encoding'])
          # Report missing date point values if two dates are present (dateCreated & dateCreated2, etc.)
          if value_is_not_blank?(date1[i]) && value_is_not_blank?(date2[i])
            if value_is_blank?(date1_point[i])
              log_error(@warning, id, "Possible date range missing #{current_headers['date1_point']}")
            end
            if value_is_blank?(date2_point[i])
              log_error(@warning, id, "Possible date range missing #{current_headers['date2_point']}")
            end
          end
          # Report attribute values without an associated date value
          if value_is_blank?(date1[i])
            if value_is_not_blank?(key_date[i])
              log_error(@warning, id, "Unnecessary #{current_headers['key_date']} value for blank #{current_headers['date1']}")
            end
            if value_is_not_blank?(encoding[i]) && value_is_blank?(date2[i])
              log_error(@warning, id, "Unnecessary #{current_headers['encoding']} value for blank #{current_headers['date1']}")
            end
            if value_is_not_blank?(date1_qualifier[i])
              log_error(@warning, id, "Unnecessary #{current_headers['date1_qualifier']} value for blank #{current_headers['date1']}")
            end
            if value_is_not_blank?(date1_point[i])
              log_error(@warning, id, "Unnecessary #{current_headers['date1_point']} value for blank #{current_headers['date1']}")
            end
          end
          if value_is_blank?(date2[i])
            if value_is_not_blank?(date2_qualifier[i])
              log_error(@warning, id, "Unnecessary #{current_headers['date2_qualifier']} value for blank #{current_headers['date2']}")
            end
            if value_is_not_blank?(date2_point[i])
              log_error(@warning, id, "Unnecessary #{current_headers['date2_point']} value for blank #{current_headers['date2']}")
            end
          end
          if value_is_blank?(date3[i])
            if value_is_not_blank?(date3_key_date[i])
              log_error(@warning, id, "Unnecessary #{current_headers['date3_key_date']} value for blank #{current_headers['date3']}")
            end
            if value_is_not_blank?(date3_encoding[i])
              log_error(@warning, id, "Unnecessary #{current_headers['date3_encoding']} value for blank #{current_headers['date3']}")
            end
            if value_is_not_blank?(date3_qualifier[i])
              log_error(@warning, id, "Unnecessary #{current_headers['date3_qualifier']} value for blank #{current_headers['date3']}")
            end
          end
          # Report dates declared w3cdtf but invalid syntax
          if value_is_not_blank?(date1[i]) && encoding[i] == 'w3cdtf' && /^\d\d\d\d$|^\d\d\d\d-\d\d$|^\d\d\d\d-\d\d-\d\d$/.match(date1[i].to_s) == nil
            log_error(@error, id, "Date #{date1[i]} in #{current_headers['date1']} does not match stated #{encoding[i]} encoding")
          end
          if value_is_not_blank?(date2[i]) && encoding[i] == 'w3cdtf' && /^\d\d\d\d$|^\d\d\d\d-\d\d$|^\d\d\d\d-\d\d-\d\d$/.match(date2[i].to_s) == nil
            log_error(@error, id, "Date #{date2[i]} in #{current_headers['date2']} does not match stated #{encoding[i]} encoding")
          end
          if value_is_not_blank?(date3[i]) && date3_encoding[i] == 'w3cdtf' && /^\d\d\d\d$|^\d\d\d\d-\d\d$|^\d\d\d\d-\d\d-\d\d$/.match(date3[i].to_s) == nil
            log_error(@error, id, "Date #{date3[i]} in #{current_headers['date3']} does not match stated #{date3_encoding[i]} encoding")
          end
          # Get key dates for comparison across date types
          if value_is_not_blank?(date1[i]) || value_is_not_blank?(date2[i])
            if key_dates.keys.include?(i)
              key_dates[i] << key_date[i]
            else
              key_dates[i] = [key_date[i]]
            end
          end
          if value_is_not_blank?(date3[i])
            if key_dates.keys.include?(i)
              key_dates[i] << date3_key_date[i]
            else
              key_dates[i] = [date3_key_date[i]]
            end
          end
        end
      end
    end

    # Report if key date not declared or declared multiple times
    key_dates.each do |i, d|
      valid_values = d.select {|x| x == "yes"}
      if valid_values.size > 1
        log_error(@error, get_druid_or_row_number(i), "Multiple key dates declared")
      elsif valid_values.size == 0
        log_error(@warning, get_druid_or_row_number(i), "No key date declared")
      end
    end

    ## Issuance

    # Report invalid issuance term
    all_issuance = select_by_pattern(@header_row_terms, 'issuance')
    all_issuance.each do |issuance|
      report_invalid_values_by_header(issuance, @issuance_terms)
    end
  end

  def validate_subject
    # Report missing subject subelement, subject type without associated value, and invalid subject subelement type
    subject_header_parts = collect_by_pattern(@header_row_terms, /^(su\d+:p[1-5]:)/)
    subject_header_parts.merge!(collect_by_pattern(@header_row_terms, /^(sn\d+:p[1-5]:)/))
    value_type_indexes = {}
    subject_header_parts.each_value do |v|
      value = v.index {|x| x.match(/:value$|:name$/)}
      type = v.index {|x| x.match(/:type$|:nameType$/)}
      if value == nil
        log_error(@error, "row 1", "Missing subject value column header for #{v[type]}")
      elsif type == nil
        log_error(@error, "row 1", "Missing subject type column header for #{v[value]}")
      else
        value_type_indexes[@header_row.find_index(v[value])] = @header_row.find_index(v[type])
      end
    end
    value_type_indexes.each do |value, type|
      value_column = @spreadsheet.column(value+1)
      type_column = @spreadsheet.column(type+1)
      value_column.each_with_index do |v, i|
        next if i <= @header_row_index
        next if value_is_blank?(v) && value_is_blank?(type_column[i])
        if value_is_not_blank?(v) && value_is_blank?(type_column[i])
          log_error(@error, get_druid_or_row_number(i), "Missing subject type in #{@header_row[type]}")
        elsif value_is_blank?(v) && value_is_not_blank?(type_column[i])
          log_error(@warning, get_druid_or_row_number(i), "Subject type provided but subject is empty in #{@header_row[value]}")
        elsif value_is_not_blank?(v) && value_is_not_error?(v)
          if value_column[@header_row_index].match(/^su\d+:|^sn\d+:p[2-5]/) && !@subject_subelements.include?(type_column[i])
            log_error(@error, get_druid_or_row_number(i), "Invalid subject type \"#{type_column[i]}\" in #{@header_row[type]}")
          elsif value_column[@header_row_index].match(/^sn\d+:p1/) && !@name_type_terms.include?(type_column[i])
            log_error(@error, get_druid_or_row_number(i), "Invalid name type \"#{type_column[i]}\" in #{@header_row[type]}")
          end
        end
      end
    end
  end

  def validate_location
    # Report missing purl values
    report_blank_values_by_header('lo:purl', @warning)
  end

  # Output error info
  # ERROR: data is invalid MODS or does not meet baseline SUL requirements
  # WARNING: data suggests an error, extra data (ex. date encoding without a date
  #   value) may be present, or data does not meet SUL recommendations
  # INFO: not necessarily an error, for user to review
  def log_error(error_type, locator, msg)
    if error_type == @fail
      write_fail_to_output(error_type, msg, locator)
    else
      @errors[error_type] << [error_type, msg, locator]
    end
  end

  def report_errors
    if @errors.values.flatten.compact == []
      return
    else
      write_errors_to_output
    end
  end

  def write_fail_to_output(error_type, msg, locator)
    @report = CSV.new(File.open('./public/rps_validator/report.csv', 'w'))
    @report << ["Type", "Description", "Locator"]
    @report << [error_type, msg, locator]
    @report.close
  end

  def write_errors_to_output
    @report = CSV.new(File.open('./public/rps_validator/report.csv', 'w'))
    @report << ["Type", "Description", "Locator"]
    report_error_type(@error)
    report_error_type(@warning)
    report_error_type(@info)
    @report.close
  end

  def report_error_type(type)
    @errors[type].each do |e|
      @report << e
    end
  end


  # Skip rows before headers and headers
  def skip_to_data?(field, value)
    return true if field.index(value) <= @header_row_index
  end

  # Identify effectively blank strings and arrays
  def value_is_blank?(value)
    return true if value == nil
    if value.is_a? String
      return true if value.strip.empty?
    elsif value.is_a? Array
      return true if value.compact.join("").strip == ""
    end
  end

  # Identify non-blank strings and arrays
  def value_is_not_blank?(value)
    return true if !value_is_blank?(value)
  end

  # Identify cell errors
  def value_is_error?(value)
    return true if @cell_errors.include?(value)
  end

  # Identify non-cell-errors
  def value_is_not_error?(value)
    return true unless @cell_errors.include?(value)
  end

  # Determine whether row has any content
  def row_has_content?(index)
    return true unless @blank_row_index.include?(index)
  end

  # Determine whether value is missing from a row with other content
  def value_is_blank_in_nonblank_row?(value, index)
    return true if value_is_blank?(value) && row_has_content?(index)
  end

  # Determine whether value is present in given term list
  def value_not_in_term_list?(value, termlist)
    return true if !value_is_blank?(value) && !termlist.include?(value)
  end

  # Check for duplicates in given list of values
  def has_duplicates?(terms)
    return true if terms.compact.size != terms.compact.uniq.size
  end

  # Return list of duplicate terms as string
  def get_duplicates(terms)
    return terms.compact.group_by {|d| d}.select {|k, v| v.size > 1}.to_h.keys.join(", ")
  end

  # Return druid, or row number if druid is not present, of a given value
  def get_druid_or_row_number(index)
    if value_is_blank?(@druids[index])
      return "row #{index+1}"
    else
      return @druids[index]
    end
  end

  # Get column letter reference from index
  def get_column_ref(i)
    name = 'A'
    i.times { name.succ! }
    return name
  end

  # Return array of headers that match given pattern
  def select_by_pattern(headers, pattern)
    return headers.select {|h| h.match(pattern)}
  end

  # Return hash with key=pattern matched, value=array of headers matching pattern
  # Supplied regex must indicate capture group
  def collect_by_pattern(headers, pattern)
    return headers.select {|h| h.match(pattern)}.group_by {|h| h.match(pattern)[1]}
  end

  # Return a column of values with the given header
  def get_values_by_header(header)
    return unless @header_row_terms.include?(header)
    return @spreadsheet.column(@header_row.find_index("#{header}") + 1)
  end

  # Report blank values present in a column with a given header
  def report_blank_values_by_header(header, report_level)
    return unless @header_row_terms.include?(header)
    values = @spreadsheet.column(@header_row.find_index(header) + 1)
    values.each_with_index do |v, i|
      next if i <= @header_row_index
      if value_is_blank_in_nonblank_row?(v, i)
        log_error(report_level, get_druid_or_row_number(i), "Blank #{header}")
      end
    end
  end

  # Report invalid values (given a list of valid ones) in a column with a given header
  def report_invalid_values_by_header(header, valid_terms)
    return unless @header_row_terms.include?(header)
    values = get_values_by_header(header)
    values.each_with_index do |v, i|
      next if i <= @header_row_index
      next if value_is_error?(v)
      report_invalid_value(v, valid_terms, get_druid_or_row_number(i), header)
    end
  end

  # Report if a given value is not in a given termlist
  def report_invalid_value(value, valid_terms, id, header)
    if value_is_not_blank?(value) && value_not_in_term_list?(value, valid_terms) && value_is_not_error?(value)
      log_error(@error, id, "Invalid term \"#{value}\" in #{header}")
    end
  end

  # Check that date syntax matches specified encoding
  # NOT IN USE
  def check_date_encoding(date_value, encoding)
    date = date_value.to_s.strip
    case encoding
    when 'w3cdtf'
      return true if date.match(/^[\d]{4}$/)
      return true if date.match(/^[\d]{4}-[\d]{2}$/)
      return true if date.match(/^[\d]{4}-[\d]{2}-[\d]{2}$/)
    when 'edtf'
      return true if date.match(/^-?[\d]{4}$/)
    when 'marc'
      return true if date.match(/^[\du]{4}$/)
      return true if date.match(/^[\d]{1,3}$/)
      return true if date.match(/^[\d]{6}$/)
    end
    if ['w3cdtf', 'edtf', 'marc'].include?(encoding)
      return FALSE
    else
      return TRUE
    end
  end

end
