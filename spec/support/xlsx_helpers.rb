require 'zip'
require 'nokogiri'
require 'cgi'

module XlsxHelpers
  def xlsx_entry(xlsx_data, entry_name)
    content = nil

    Zip::File.open_buffer(StringIO.new(xlsx_data)) do |zip|
      entry = zip.read(entry_name)
      content = entry.respond_to?(:read) ? entry.read : entry
    end

    content
  end

  def worksheet_xml(xlsx_data)
    xlsx_entry(xlsx_data, 'xl/worksheets/sheet1.xml')
  end

  def worksheet_relationships_xml(xlsx_data)
    xlsx_entry(xlsx_data, 'xl/worksheets/_rels/sheet1.xml.rels')
  end

  def table_xml(xlsx_data)
    xlsx_entry(xlsx_data, 'xl/tables/table1.xml')
  end

  def shared_strings_xml(xlsx_data)
    xlsx_entry(xlsx_data, 'xl/sharedStrings.xml')
  end

  def worksheet_row_texts(xlsx_data)
    doc = Nokogiri::XML(worksheet_xml(xlsx_data))
    doc.remove_namespaces!
    shared_strings = xlsx_shared_strings(xlsx_data)

    doc.xpath('//row').map do |row|
      row.xpath('./c').flat_map do |cell|
        if cell['t'] == 's'
          shared_strings.fetch(cell.at_xpath('./v').text.to_i)
        else
          cell.xpath('.//t').map(&:text)
        end
      end
    end
  end

  def xml_escape(value)
    CGI.escapeHTML(value)
  end

  def xlsx_shared_strings(xlsx_data)
    doc = Nokogiri::XML(shared_strings_xml(xlsx_data))
    doc.remove_namespaces!

    doc.xpath('//si').map do |shared_string|
      shared_string.xpath('.//t').map(&:text)
    end
  rescue Errno::ENOENT
    []
  end
end

RSpec.configure do |config|
  config.include XlsxHelpers
end
