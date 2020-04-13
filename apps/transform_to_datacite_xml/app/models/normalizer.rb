class Normalizer
  # Your code goes here...
  require 'nokogiri'

  # Linefeed character entity reference
  LINEFEED = '&#10;'.freeze

  # Select all single <dateCreated> and <dateIssued> fields
  LONE_DATE_XPATH = '//mods:originInfo/mods:dateCreated[1][not(following-sibling::*[1][self::mods:dateCreated])]' \
                    ' | //mods:originInfo/mods:dateIssued[1][not(following-sibling::*[1][self::mods:dateIssued])]'.freeze

  # Select all <dateCreated> and <dateIssued> fields
  DATE_CREATED_ISSUED_XPATH = '//mods:dateCreated | //mods:dateIssued'.freeze

  # The official MODS namespace, courtesy of the Library of Congress
  MODS_NAMESPACE = 'http://www.loc.gov/mods/v3'.freeze

  # Selects <abstract>, <tableOfContents> and <note> when no namespace is present
  LINEFEED_XPATH = '//abstract | //tableOfContents | //note'.freeze

  # Selects <abstract>, <tableOfContents> and <note> when a namespace is present
  LINEFEED_XPATH_NAMESPACED = '//ns:abstract | //ns:tableOfContents | //ns:note'.freeze

  # Checks if a node has attributes that we make exeptions for. There are two such exceptions.
  #
  # * A "collection" attribute with the value "yes" <em>on a typeOfResource tag</em>.
  # * A "manuscript" attribute with the value "yes" <em>on a typeOfResource tag</em>.
  #
  # Nodes that fall under any of these exceptions should not be deleted, even if they have no content.
  #
  # @param  [Nokogiri::XML::Element]   node    An XML node.
  # @return [Boolean]                  true if the node contains any of the exceptional attributes, false otherwise.
  def exceptional?(node)
    return false if node.nil?

    tag = node.name
    attributes = node.attributes

    return false if attributes.empty?

    attributes.each do |key, value|
      # next unless tag == 'typeOfResource'
      next unless tag == 'resourceType'
      # Note that according to the MODS schema, any other value than 'yes' for these attributes is invalid
      # if (key == 'collection' && value.to_s.casecmp('yes').zero?) ||
      #    (key == 'manuscript' && value.to_s.casecmp('yes').zero?)
      if key == 'resourceTypeGeneral' && value.to_s != (nil || "")
        return true
      end
    end
    false
  end

  # Recursive helper method for {Normalizer#clean_linefeeds} to do string substitution.
  #
  # @param [Nokogiri::XML::Element]   node   An XML node
  # @return [String]                  A string composed of the entire contents of the given node,
  #                                   with substitutions made as described for {#clean_linefeeds}.
  def substitute_linefeeds(node)
    new_text = ''

    # If we substitute in '&#10;' by itself, Nokogiri interprets that and then prints '&amp;#10;' when printing the document later. This
    # is an ugly way to add linefeed characters in a way that we at least get well-formatted output in the end.
    if node.text?
      new_text = node.content.gsub(/(\r\n|\n|\r|\\n)/, Nokogiri::HTML(LINEFEED).text)
    else
      if node.node_name == 'br'
        new_text += Nokogiri::HTML(LINEFEED).text
      elsif node.node_name == 'p'
        new_text += Nokogiri::HTML(LINEFEED).text + Nokogiri::HTML(LINEFEED).text
      end

      node.children.each do |c|
        new_text += substitute_linefeeds(c)
      end
    end
    new_text
  end

  # Given the root of an XML document, replaces linefeed characters inside <tableOfContents>, <abstract> and <note> XML node by &#10;
  # \n, \r, <br> and <br/> are all replaced by a single &#10;
  # <p> is replaced by two &#10;
  # </p> is removed
  # \r\n is replaced by &#10;
  # Any tags not listed above are removed. MODS 3.5 does not allow for anything other than text inside these three nodes.
  #
  # @param   [Nokogiri::XML::NodeSet]    node_list  All <tableOfContents>, <abstract> and <node> elements.
  # @return  [Void]                      This method doesn't return anything, but introduces
  #                                      UTF-8 linefeed characters in place, as described above.
  def clean_linefeeds(node_list)
    node_list.each do |current_node|
      new_text = substitute_linefeeds(current_node)
      current_node.children.remove
      current_node.content = new_text
    end
  end

  # Cleans up the text of a node:
  #
  # * Removes extra whitespace at the beginning and end.
  # * Removes any consecutive whitespace within the string.
  #
  # @param [String]   s   The text of an XML node.
  # @return [String]  The cleaned string, as described. Returns nil if the input is nil, or if the input is an empty string.
  def clean_text(s)
    return nil unless !s.nil? && s != ''
    s.gsub(/\s+/, ' ').strip
  end

  # Removes empty attributes from a given node.
  #
  # @param [Nokogiri::XML::Element]   node An XML node.
  # @return [Void]                    This method doesn't return anything, but modifies the XML tree starting at the given node.
  def remove_empty_attributes(node)
    children = node.children
    attributes = node.attributes

    attributes.each do |key, value|
      node.remove_attribute(key) if value.to_s.strip.empty?
    end

    children.each do |c|
      remove_empty_attributes(c)
    end
  end

  # Removes empty nodes from an XML tree. See {#exceptional?} for nodes that are kept even if empty.
  #
  # @param  [Nokogiri::XML::Element]   node An XML node.
  # @return [Void]                     This method doesn't return anything, but modifies the XML tree starting at the given node.
  def remove_empty_nodes(node)
    children = node.children

    if node.text?
      return node.remove if node.to_s.strip.empty?
      return
    elsif !children.empty?
      children.each do |c|
        remove_empty_nodes(c)
      end
    end

    node.remove if !exceptional?(node) && node.children.empty?
  end

  # Removes leading and trailing spaces from a node.
  #
  # @param  [Nokogiri::XML::Element]  node An XML node.
  # @return [Void]                    This method doesn't return anything, but modifies the entire XML tree starting at the
  #                                   the given node, removing leading and trailing spaces from all text. If the input is nil,
  #                                   an exception will be raised.
  def trim_text(node)
    children = node.children

    if node.text?
      node.parent.content = node.text.strip
    else
      children.each do |c|
        trim_text(c)
      end
    end
  end

  # Sometimes there are spurious decimal digits within the date fields. This method removes any trailing decimal points within
  # <dateCreated> and <dateIssued>.
  #
  # @param [Nokogiri::XML::NodeSet]   nodes  A set of all affected <dateCreated> and <dateIssued> elements.
  # @return [Void]                    The given document is modified in place.
  def clean_date_values(nodes)
    nodes.each do |current_node|
      current_node.content = current_node.content.sub(/(.*)\.\d+$/, '\1')
    end
  end

  # Normalizes the given MODS XML document according to the Stanford guidelines.
  #
  # @param  [Nokogiri::XML::Element]  root  The root of a MODS XML document.
  # @return [Void]                    The given document is modified in place.
  def normalize_mods_document(root)
    node_list = if root.namespace.nil?
                  root.xpath(LINEFEED_XPATH)
                else
                  root.xpath(LINEFEED_XPATH_NAMESPACED, 'ns' => root.namespace.href)
                end
    clean_linefeeds(node_list) # Do this before deleting <br> and <p> with remove_empty_nodes()

    remove_empty_attributes(root)
    remove_empty_nodes(root)
    trim_text(root)
    clean_date_values(root.xpath(DATE_CREATED_ISSUED_XPATH, 'mods' => MODS_NAMESPACE))
  end

  # Normalizes the given MODS XML document according to the Stanford guidelines.
  #
  # @deprecated Use normalize_mods_document instead.
  # @param  [Nokogiri::XML::Element]  root  The root of a MODS XML document.
  # @return [Void]                    The given document is modified in place.
  def normalize_document(root)
    normalize_mods_document(root)
  end

  # Normalizes the given XML document string according to the Stanford guidelines.
  #
  # @param  [String]   xml_string    An XML document
  # @return [String]                 The XML string, with normalizations applied.
  def normalize_xml_string(xml_string)
    doc = Nokogiri::XML(xml_string)
    normalize_document(doc.root)
    doc.to_s
  end
end
