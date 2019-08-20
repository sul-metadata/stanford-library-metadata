require 'roo'

class Validator

  attr_reader :header_row_index, :header_row_terms, :errors, :exit, :value_type_indexes, :selected_headers, :druids, :formula_errors, :report

  def initialize(filename)
    @filename = filename
    @template = './apps/replayable_spreadsheet_validator/modsulator_template.xml'
    @extension = File.extname(@filename)
    @report = CSV.new(File.open('./public/rps_validator/report.csv', 'w'))

    @exit = false
    @value_type_indexes = {}
    @druids = []
    @sourceids = []
    @blank_row_index = []
    @missing_sourceids = []

    ## Additional accessors for testing
    @header_row_index = nil
    @header_row_terms = []
    @selected_headers = {}

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

    @formula_errors = {
      'na' => [],
      'ref' => [],
      'zero' => [],
      'name' => [],
      'value' => []
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

    @date_value_types = {
      'date1' => '',
      'key_date' => '',
      'encoding' => '',
      'date1_qualifier' => '',
      'date1_point' => '',
      'date2' => '',
      'date2_qualifier' => '',
      'date2_point' => '',
      'date3' => '',
      'date3_key_date' => '',
      'date3_encoding' => '',
      'date3_qualifier' => ''
    }

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
    report_formula_errors
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
        xlsx_open = Roo::Excelx.new(@filename)
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
      @xlsx = Roo::Excelx.new(@filename)
      i = 0
      @xlsx.each_row_streaming(pad_cells: true, max_rows: 10) do |row|
        row.map! {|x| (x == nil ? x.to_s : x.value) }
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

    subject_headers = get_subject_headers
    subject_headers.each_value do |v|
      value = v.index {|x| x.match(/:value$|:name$/)}
      type = v.index {|x| x.match(/:type$|:nameType$/)}
      if value == nil
        log_error(@error, "headers", "Missing subject value column header for #{v[type]}")
      elsif type == nil
        log_error(@error, "headers", "Missing subject type column header for #{v[value]}")
      else
        @value_type_indexes[@header_row.find_index(v[value])] = @header_row.find_index(v[type])
      end
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
    row_index = 0
    case @extension
    when '.csv'
      CSV.foreach(@filename) do |row|
        if report_blank_row(row, row_index) || row_index <= @header_row_index
          row_index += 1
        else
          process_row(row, row_index)
          row_index += 1
        end
      end
    when '.xlsx'
      @xlsx.each_row_streaming(pad_cells: true) do |row|
        row.map! {|x| (x == nil ? x.to_s : x.value) }
        if report_blank_row(row, row_index) || row_index <= @header_row_index
          row_index += 1
        else
          process_row(row, row_index)
          row_index += 1
        end
      end
    end
    report_duplicate_druids
    report_duplicate_sourceids
    report_missing_sourceids
  end

  def get_date_headers
    grouped_date_headers = {}
    # Get date headers present in spreadsheet and group by prefix(es)
    all_date_headers = collect_by_pattern(@header_row_terms, /^(o?r?[23]?:?dt\d?:)/)
    # Iterate over the set of headers for each prefix
    all_date_headers.each do |prefix, originInfo_instance_headers|
      grouped_date_headers["#{prefix}"] = {}
      # Iterate over the set of date headers for each date type (dateCreated, etc.)
      @date_elements.each do |date_group_term|
        # Get date headers actually in spreadsheet for this group
        grouped_date_headers["#{prefix}"]["#{date_group_term}"] = select_by_pattern(originInfo_instance_headers, /#{date_group_term}/)
      end
    end
    return grouped_date_headers
  end

  def process_row(row, row_index)
    druid = row[0]
    @druids << druid
    @sourceids << row[1]
    id = druid
    if value_is_blank?(druid)
      id = "row #{row_index + 1}"
      log_error(@error, id, "Missing druid")
    else
      validate_druid(druid)
    end
    validate_cells_in_row(row, row_index)
    validate_title(row, row_index, id, @selected_headers['title_type'])
    validate_name(row, id, @selected_headers['name_type'])
    validate_type_of_resource(row, row_index, id, @selected_headers['type_of_resource'])
    validate_date(row, id, @selected_headers['dates'])
    validate_issuance(row, id, @selected_headers['issuance'])
    validate_subject(row, id)
    validate_location(row, row_index, id)
    row_index += 1
  end

  def report_blank_row(row, row_index)
    if row.compact.join("").match(/^\s*$/)
      log_error(@error, "row #{row_index + 1}", "Blank row")
      @blank_row_index << row_index
      return true
    end
    return false
  end

  def validate_druid(druid)
    unless druid_is_valid_pattern?(druid)
      log_error(@error, druid, "Invalid druid")
    end
  end

  def druid_is_valid_pattern?(druid)
    if druid.strip.match(/^[a-z][a-z][0-9][0-9][0-9][a-z][a-z][0-9][0-9][0-9][0-9]$/)
      return true
    end
    return false
  end

  def validate_cells_in_row(row, row_index)
    row.each_with_index do |cell, cell_index|
      validate_cells(cell, cell_index, row_index)
    end
  end

  def validate_cells(cell, cell_index, row_index)
    return false if cell == nil || value_is_blank?(cell)
    cell_ref = "#{get_column_ref(cell_index)}#{row_index + 1}"
    validate_characters(cell, cell_ref) if cell.class == String
    validate_xlsx_cell_types(cell, cell_ref) if @extension == '.xlsx'
    identify_formula_errors(cell, cell_ref)
    if cell_index == 1
      identify_missing_sourceid(cell, cell_ref)
    end
  end

  def validate_characters(cell, cell_ref)
    if cell.match(/[\r\n]+/)
      log_error(@error, cell_ref, "Line break in cell text")
    elsif cell.match(/[\u0000-\u001F]/)
      log_error(@error, cell_ref, "Control character in cell text")
    end
    if cell.match(/^["“”][^"]*/)
      log_error(@warning, cell_ref, "Cell value begins with unclosed double quotation mark")
    end
  end

  def validate_xlsx_cell_types(cell, cell_ref)
    if cell.class == Integer
      log_error(@info, cell_ref, "Non-text Excel formatting: #{cell.class}")
    elsif cell.class != String
      log_error(@warning, cell_ref, "Non-text Excel formatting: #{cell.class}")
    end
  end

  def identify_formula_errors(cell, cell_ref)
    case cell.to_s
    when '#N/A'
      @formula_errors['na'] << cell_ref
    when '#REF!'
      @formula_errors['ref'] << cell_ref
    when '0'
      @formula_errors['zero'] << cell_ref
    when '#NAME?'
      @formula_errors['name'] << cell_ref
    when '#VALUE!'
      @formula_errors['value'] << cell_ref
    end
  end

  def identify_missing_sourceid(cell, cell_ref)
    if value_is_blank?(cell)
      @missing_sourceids << cell_ref
    end
  end

  def report_duplicate_druids
    # Report duplicate druids
    if has_duplicates?(@druids)
      log_error(@error, get_duplicates(@druids), "Duplicate druids")
    end
  end

  def report_missing_sourceids
    # Report empty cells in source ID column
    log_error(@info, @missing_sourceids.join(", "), "Blank source ID")
  end

  def report_duplicate_sourceids
    # Report duplicate source IDs
    if has_duplicates?(@sourceids.compact)
      log_error(@info, get_duplicates(@sourceids), "Duplicate source IDs")
    end
  end

  def report_formula_errors
    formula_error_messages = {
      'na' => ['#N/A error in cell', @error],
      'ref' => ['#REF! error in cell', @error],
      'zero' => ['Cell value is 0', @warning],
      'name' => ['#NAME? error in cell', @error],
      'value' => ['#VALUE? error in cell', @error]
    }
    @formula_errors.each do |error_type, errors|
      next if value_is_blank?(errors)
      log_error(formula_error_messages[error_type][1], errors.join(', '), formula_error_messages[error_type][0])
    end
  end

  def validate_title(row, row_index, id, type_headers)
    # Report missing title in first title column
    report_blank_value_by_header('ti1:title', row, row_index, id, @error)
    # Report invalid title type
    type_headers.each do |h|
      report_invalid_value_by_header(h, row, id, @title_type_terms)
    end
  end

  def validate_name(row, id, type_headers)
    # Report invalid name type
    type_headers.each do |h|
      report_invalid_value_by_header(h, row, id, @name_type_terms)
    end
    # Report invalid usage value ("primary" is only value allowed)
    report_invalid_value_by_header('na1:usage', row, id, ['primary'])
  end

  def validate_type_of_resource(row, row_index, id, headers)
    # Report missing (required) or invalid type of resource value
    headers.each do |h|
      if h == "ty1:typeOfResource"
        report_blank_value_by_header(h, row, row_index, id, @warning)
      end
      report_invalid_value_by_header(h, row, id, @type_of_resource_terms)
    end
    # Report invalid values in ty1:manuscript
    report_invalid_value_by_header('ty1:manuscript', row, id, @yes_terms)
  end

  def validate_date(row, id, grouped_date_headers)
    key_dates = []
    grouped_date_headers.each do |prefix, date_groups|
      # prefix = dt, or2, or3
      # Skip to next if date type for this iteration is not in spreadsheet
      next if value_is_blank?(date_groups)
      # Base of date term (dateCreated, etc.) and suffixes for date headers (keyDate, etc.)
      # Identify values under each possible header for given date type if header is present
      date_groups.each do |date_group_term, date_group_headers|
        current_headers, current_values = get_current_date_headers_and_values(prefix, date_group_term, date_group_headers, row)
        report_invalid_date_values(current_headers, current_values, id)
        report_missing_date_point_values(current_headers, current_values, id)
        report_unnecessary_date_attributes(current_headers, current_values, id)
        report_invalid_date_encoding(current_headers, current_values, id)
        # Get key dates for comparison across date types
        if value_is_not_blank?(current_values['date1']) || value_is_not_blank?(current_values['date2'])
          key_dates << current_values['key_date']
        end
        if value_is_not_blank?(current_values['date3'])
          key_dates << current_values['date3_key_date']
        end
      end
    end
    # Report if key date not declared or declared multiple times
    valid_values = key_dates.select {|x| x == "yes"}
    if valid_values.size > 1
      log_error(@error, id, "Multiple key dates declared")
    elsif valid_values.size == 0
      log_error(@warning, id, "No key date declared")
    end
  end

  def get_current_date_headers_and_values(prefix, date_group_term, date_group_headers, row)
    # date_group_term = dateCreated, dateIssued, dateCaptured, copyrightDate
    date_base = "#{prefix}#{date_group_term}"
    current_headers = {}
    current_values = @date_value_types.merge
    date_group_headers.each do |h|
      # Single date or start of range (dateCreated, etc.)
      if h == date_base
        current_values['date1'] = get_value_by_header(h, row)
        current_headers['date1'] = h
      else
        # Get values by header suffix
        h_uniq = h.gsub(date_base,"")
        case h_uniq
        when "KeyDate"
          current_values['key_date'] = get_value_by_header(h, row)
          current_headers['key_date'] = h
        when "Encoding"
          current_values['encoding'] = get_value_by_header(h, row)
          current_headers['encoding'] = h
        when "Qualifier"
          current_values['date1_qualifier'] = get_value_by_header(h, row)
          current_headers['date1_qualifier'] = h
         when "Point"
          current_values['date1_point'] = get_value_by_header(h, row)
          current_headers['date1_point'] = h
        when "2"
          current_values['date2'] = get_value_by_header(h, row)
          current_headers['date2'] = h
        when "2Qualifier"
          current_values['date2_qualifier'] = get_value_by_header(h, row)
          current_headers['date2_qualifier'] = h
        when "2Point"
          current_values['date2_point'] = get_value_by_header(h, row)
          current_headers['date2_point'] = h
        when "3"
          current_values['date3'] = get_value_by_header(h, row)
          current_headers['date3'] = h
        when "3KeyDate"
          current_values['date3_key_date'] = get_value_by_header(h, row)
          current_headers['date3_key_date'] = h
        when "3Encoding"
          current_values['date3_encoding'] = get_value_by_header(h, row)
          current_headers['date3_encoding'] = h
        when "3Qualifier"
          current_values['date3_qualifier'] = get_value_by_header(h, row)
          current_headers['date3_qualifier'] = h
        end
      end
    end
    return current_headers, current_values
  end

  def report_invalid_date_values(current_headers, current_values, id)
    # Report invalid values for each field in this date type
    report_invalid_value(current_values['key_date'], @yes_terms, id, current_headers['key_date'])
    report_invalid_value(current_values['date3_key_date'], @yes_terms, id, current_headers['date3_key_date'])
    report_invalid_value(current_values['date1_qualifier'], @date_qualifier_terms, id, current_headers['date1_qualifier'])
    report_invalid_value(current_values['date2_qualifier'], @date_qualifier_terms, id, current_headers['date2_qualifier'])
    report_invalid_value(current_values['date3_qualifier'], @date_qualifier_terms, id, current_headers['date3_qualifier'])
    report_invalid_value(current_values['date1_point'], @date_point_terms, id, current_headers['date1_point'])
    report_invalid_value(current_values['date2_point'], @date_point_terms, id, current_headers['date2_point'])
    report_invalid_value(current_values['encoding'], @date_encoding_terms, id, current_headers['encoding'])
    report_invalid_value(current_values['date3_encoding'], @date_encoding_terms, id, current_headers['date3_encoding'])
  end

  def report_missing_date_point_values(current_headers, current_values, id)
    # Report missing date point values if two dates are present (dateCreated & dateCreated2, etc.)
    if value_is_not_blank?(current_values['date1']) && value_is_not_blank?(current_values['date2'])
      if value_is_blank?(current_values['date1_point'])
        log_error(@warning, id, "Possible date range missing #{current_headers['date1_point']}")
      end
      if value_is_blank?(current_values['date2_point'])
        log_error(@warning, id, "Possible date range missing #{current_headers['date2_point']}")
      end
    end
  end

  def report_unnecessary_date_attributes(current_headers, current_values, id)
    # Report attribute values without an associated date value
    if value_is_blank?(current_values['date1'])
      if value_is_not_blank?(current_values['key_date'])
        log_error(@warning, id, "Unnecessary #{current_headers['key_date']} value for blank #{current_headers['date1']}")
      end
      if value_is_not_blank?(current_values['encoding']) && value_is_blank?(current_values['date2'])
        log_error(@warning, id, "Unnecessary #{current_headers['encoding']} value for blank #{current_headers['date1']}")
      end
      if value_is_not_blank?(current_values['date1_qualifier'])
        log_error(@warning, id, "Unnecessary #{current_headers['date1_qualifier']} value for blank #{current_headers['date1']}")
      end
      if value_is_not_blank?(current_values['date1_point'])
        log_error(@warning, id, "Unnecessary #{current_headers['date1_point']} value for blank #{current_headers['date1']}")
      end
    end
    if value_is_blank?(current_values['date2'])
      if value_is_not_blank?(current_values['date2_qualifier'])
        log_error(@warning, id, "Unnecessary #{current_headers['date2_qualifier']} value for blank #{current_headers['date2']}")
      end
      if value_is_not_blank?(current_values['date2_point'])
        log_error(@warning, id, "Unnecessary #{current_headers['date2_point']} value for blank #{current_headers['date2']}")
      end
    end
    if value_is_blank?(current_values['date3'])
      if value_is_not_blank?(current_values['date3_key_date'])
        log_error(@warning, id, "Unnecessary #{current_headers['date3_key_date']} value for blank #{current_headers['date3']}")
      end
      if value_is_not_blank?(current_values['date3_encoding'])
        log_error(@warning, id, "Unnecessary #{current_headers['date3_encoding']} value for blank #{current_headers['date3']}")
      end
      if value_is_not_blank?(current_values['date3_qualifier'])
        log_error(@warning, id, "Unnecessary #{current_headers['date3_qualifier']} value for blank #{current_headers['date3']}")
      end
    end
  end

  def report_invalid_date_encoding(current_headers, current_values, id)
    # Report dates declared w3cdtf but invalid syntax
    if value_is_not_blank?(current_values['date1']) && current_values['encoding'] == 'w3cdtf' && /^\d\d\d\d$|^\d\d\d\d-\d\d$|^\d\d\d\d-\d\d-\d\d$/.match(current_values['date1'].to_s) == nil
      log_error(@error, id, "Date #{current_values['date1']} in #{current_headers['date1']} does not match stated #{current_values['encoding']} encoding")
    end
    if value_is_not_blank?(current_values['date2']) && current_values['encoding'] == 'w3cdtf' && /^\d\d\d\d$|^\d\d\d\d-\d\d$|^\d\d\d\d-\d\d-\d\d$/.match(current_values['date2'].to_s) == nil
      log_error(@error, id, "Date #{current_values['date2']} in #{current_headers['date2']} does not match stated #{current_values['encoding']} encoding")
    end
    if value_is_not_blank?(current_values['date3']) && current_values['date3_encoding'] == 'w3cdtf' && /^\d\d\d\d$|^\d\d\d\d-\d\d$|^\d\d\d\d-\d\d-\d\d$/.match(current_values['date3'].to_s) == nil
      log_error(@error, id, "Date #{current_values['date3']} in #{current_headers['date3']} does not match stated #{current_values['date3_encoding']} encoding")
    end
  end

  def validate_issuance(row, id, headers)
    # Report invalid issuance term
    headers.each do |issuance|
      report_invalid_value_by_header(issuance, row, id, @issuance_terms)
    end
  end

  def get_subject_headers
    subject_headers = collect_by_pattern(@header_row_terms, /^(su\d+:p[1-5]:)/).merge(collect_by_pattern(@header_row_terms, /^(sn\d+:p[1-5]:)/))
    return subject_headers
  end

  def validate_subject(row, id)
    # Report missing subject subelement, subject type without associated value, and invalid subject subelement type
    @value_type_indexes.each do |value, type|
      next if value_is_blank?(row[value]) && value_is_blank?(row[type])
      if value_is_not_blank?(row[value]) && value_is_blank?(row[type])
        log_error(@error, id, "Missing subject type in #{@header_row[type]}")
      elsif value_is_blank?(row[value]) && value_is_not_blank?(row[type])
        log_error(@warning, id, "Subject type provided but subject is empty in #{@header_row[value]}")
      elsif value_is_not_blank?(row[value]) && value_is_not_blank?(row[type])
        if @header_row[value].match(/^su\d+:|^sn\d+:p[2-5]/) && !@subject_subelements.include?(row[type])
          log_error(@error, id, "Invalid subject type \"#{row[type]}\" in #{@header_row[type]}")
        elsif @header_row[value].match(/^sn\d+:p1/) && !@name_type_terms.include?(row[type])
          log_error(@error, id, "Invalid subject name type \"#{row[type]}\" in #{@header_row[type]}")
        end
      end
    end
  end

  def validate_location(row, row_index, id)
    # Report missing purl values
    report_blank_value_by_header('lo:purl', row, row_index, id, @warning)
  end

  # Output error info
  # ERROR: data is invalid MODS or does not meet baseline SUL requirements
  # WARNING: data suggests an error, extra data (ex. date encoding without a date
  # value) may be present, or data does not meet SUL recommendations
  # INFO: not necessarily an error, for user to review
  def log_error(error_type, locator, msg)
    @errors[error_type] << [error_type, msg, locator]
    if error_type == @fail
      write_errors_to_output
    end
  end

  def write_errors_to_output
    @report << ["Type", "Description", "Locator"]
    report_error_type(@fail)
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

  # Return a value with the given header
  def get_value_by_header(header, row)
    return unless @header_row_terms.include?(header)
    value = row[@header_row.find_index(header)]
    return value
  end

  # Report blank value in a row for a given header
  def report_blank_value_by_header(header, row, row_index, id, report_level)
    return unless @header_row_terms.include?(header)
    header_index = @header_row.find_index(header)
    if value_is_blank_in_nonblank_row?(row[header_index], row_index)
      log_error(report_level, id, "Blank #{header}")
    end
  end

  # Report invalid values (given a list of valid ones) in a row for a given header
  def report_invalid_value_by_header(header, row, id, valid_terms)
    return unless @header_row_terms.include?(header)
    header_index = @header_row.find_index(header)
    report_invalid_value(row[header_index], valid_terms, id, header)
  end

  # Report if a given value is not in a given termlist
  def report_invalid_value(value, valid_terms, id, header)
    if value_is_not_blank?(value) && value_not_in_term_list?(value, valid_terms) && value_is_not_error?(value)
      log_error(@error, id, "Invalid term \"#{value}\" in #{header}")
    end
  end


end
