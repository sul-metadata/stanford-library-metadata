class ModelGenerator

  def initialize

    # to process data: match on value or prefix

    @outfile = File.open('html.html', 'w')

    attribute_sets = {
      'type' => ['type'],
      'authority' => ['authority', 'authorityURI', 'valueURI'],
      'uniform_title' => ['nameTitleGroup'],
      'language' => ['lang', 'script', 'transliteration', 'altRepGroup'],
      'displayLabel' => ['displayLabel'],
      'usage' => ['usage'],
      'date' => ['encoding', 'qualifier', 'point'], #keyDate for first
      'objectPart' => ['objectPart'],
      'manuscript' => ['manuscript'],
      'eventType' => ['eventType']
    }

    # options are 0 or 1 (boolean), or max count

    # required: title, type if more than one
    @title = {
      'non_sort' => {'max' => 1, 'label' => 'field for non-sorting characters'},
      'parts' => {'max' => 1, 'label' => 'subtitle and title parts'},
      'uniform_title' => {'max' => 1, 'label' => 'uniform title'}, # include for name as well, and authority fields
      'displayLabel' => {'max' => 1, 'label' => 'display label'},
      'language' => {'max' => 1, 'label' => 'language of title'}
    }

    # required: namePart, usage for first, type
    @name = {
      'affiliation' => {'max' => 5, 'label' => 'affiliation'},
      'nameIdentifier' => {'max' => 3, 'label' => 'person identifier (not name authority)'}, #type
      'role' => {'max' => 3, 'label' => 'role'}, #type, authority
      'authority' => {'max' => 1, 'label' => 'name authority'},
      'language' => {'max' => 1, 'label' => 'language of name'}
    }

    @typeOfResource = {
      'manuscript' => {'max' => 1, 'label' => 'manuscript designation'} #first only
    }

    @genre = {
      'displayLabel' => {'max' => 1, 'label' => 'display label'},
      #'type' => 1,
      'authority' => {'max' => 1, 'label' => 'genre authority'}
    }

    @originInfo = {
      'displayLabel' => {'max' => 1, 'label' => 'display label'},
      'eventType' => {'max' => 1, 'label' => 'event type'},
      'place_text' => {'max' => 1, 'label' => 'place name as text'}, #authority, must represent same location as code if given
      'place_code' => {'max' => 1, 'label' => 'place name as geographic code'}, #authority
      'publisher' => {'max' => 1, 'label' => 'publisher'}, #language with different codes
      'dateCreated' => {'max' => 3, 'label' => 'date of creation'}, #date with different codes, keyDate for first
      'dateIssued' => {'max' => 3, 'label' => 'date of issuance or publication'}, #date with different codes, keyDate for first
      'dateCaptured' => {'max' => 2, 'label' => 'capture date'}, #date with different codes, keyDate for first
      'copyrightDate' => {'max' => 2, 'label' => 'copyright date'}, #date with different codes, keyDate for first
      #dateOther
      'edition' => {'max' => 1, 'label' => 'edition'},
      'issuance' => {'max' => 1, 'label' => 'issuance'},
      'frequency' => {'max' => 1, 'label' => 'frequency'}
    }

    @language = {
      'objectPart' => {'max' => 1, 'label' => 'designation for the part of the resource that uses this language'},
      #'authority' => 1,
      'scriptTerm' => {'max' => 1, 'label' => 'script'} #type, authority
    }

    @top_level_element_counts = {
      'titleInfo' => {'min'=> 1, 'max' => 10, 'opt' => @title, 'label' => 'Title'},
      'name' => {'min'=> 0, 'max' => 30, 'opt' => @name, 'label' => 'Name'},
      'typeOfResource' => {'min'=> 1, 'max' => 3, 'opt' => @typeOfResource, 'label' => 'Type of resource'},
      'genre' => {'min'=> 0, 'max' => 10, 'opt' => @genre, 'label' => 'Genre'},
      #'originInfo' => 3,
      'originInfo' => {'min'=> 0, 'max' => 1, 'opt' => @originInfo, 'label' => 'Origin info'},
      'language' => {'min'=> 0, 'max' => 10, 'opt' => @language, 'label' => 'Language'},
      'physicalDescription' => {'min'=> 0, 'max' => 1, 'label' => 'Physical description'},
      #'physicalDescription_brief' => 2,
      'abstract' => {'min'=> 0, 'max' => 1, 'label' => 'Abstract'},
      'tableOfContents' => {'min'=> 0, 'max' => 1, 'label' => 'Table of contents'},
      'note' => {'min'=> 0, 'max' => 20, 'label' => 'Note'},
      'subject_name_title' => {'min'=> 0, 'max' => 30, 'label' => 'Name subject'},
      'subject_other' => {'min'=> 0, 'max' => 50, 'label' => 'Other subject'},
      #'subject_hierarchical_geographic' => 1,
      #'subject_cartographics' => 2,
      'subject_cartographics' => {'min'=> 0, 'max' => 1, 'label' => 'Cartographic subject'},
      'identifier' => {'min'=> 0, 'max' => 5, 'label' => 'Identifier'},
      'location' => {'min'=> 0, 'max' => 1, 'label' => 'Location'},
      'relatedItem' => {'min'=> 0, 'max' => 100, 'label' => 'Related item'},
      #'relatedItem' => 3,
      #'relatedItem_brief' => 97,
      'geo_extension' => {'min'=> 0, 'max' => 1, 'label' => 'Geo extension'}
    }

    generate_html
  end


  def generate_html
    @outfile.write("<form>\n")
    @top_level_element_counts.each do |element, params|
      opt = []
      if params.keys.include?('opt')
        opt = params['opt']
      end
      generate_element_html(element, params['min'], params['max'], opt, params['label'])
    end
    @outfile.write("</form>")
    @outfile.close
  end

  def generate_element_html(element, min, max, options_source, label)
    html_set = "\t<fieldset>\n\t\t<legend>#{label}</legend>\n"
    if max == 1
      html_set << generate_paragraph_item(generate_option_html(element, label))
    else
      html_set << generate_paragraph_item(generate_numeric_html(element, min, max, label))
    end
    if options_source != []
      html_set << "\t\t<ul>\n"
      options_source.each do |opt, params|
        if params['max'] == 1
          html_set << generate_list_item(generate_option_html(opt, params['label']))
        else
          html_set << generate_list_item(generate_numeric_html(opt, 0, params['max'], params['label']))
        end
      end
      html_set << "\t\t</ul>\n"
    end
    html_set << "\t</fieldset>\n"
    @outfile.write(html_set)
  end

  def generate_numeric_html(element, min, max, label)
    html = "Number of #{label.downcase} columns (min #{min}, max #{max}): <input type=\"number\" name=\"#{element}\" min=\"#{min}\" max=\"#{max}\" value=\"#{min}\">"
    return html
  end

  def generate_option_html(option, label)
    html = "Include #{label.downcase}? <input type=\"radio\" name=\"#{option}\" value=\"true\">Yes <input type=\"radio\" name=\"#{option}\" value=\"false\" checked>No"
    return html
  end

  def generate_list_item(item)
    html = "\t\t\t<li>" + item + "</li>\n"
    return html
  end

  def generate_paragraph_item(item)
    html = "\t\t<p>" + item + "</p>\n"
    return html
  end

end
