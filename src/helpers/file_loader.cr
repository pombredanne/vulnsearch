require "../models/cve"
require "xml"
require "zlib"

module Vulnsearch
  class FileLoader
    def initialize
      pattern = File.join(Vulnsearch::XML_DATA_DIR, "*.xml.gz")
      @data_files = Dir.glob(pattern)
      @data_files.sort!
    end

    def load_all_files
      @data_files.each do |file|
        print "Loading data from #{file}... "
        parse_data(file)
        puts "Done."
      end

      0
    end

    def parse_data(nvdcve_file)
      parser_opts = XML::ParserOptions::RECOVER |
                    XML::ParserOptions::NONET |
                    XML::ParserOptions::NOBLANKS
      xml_doc = File.open(nvdcve_file, "r") do |file|
        Gzip::Reader.open(file) do |inflate|
          XML.parse(inflate.gets_to_end, parser_opts)
        end
      end

      entries = xml_doc.xpath_nodes("//*[local-name()=\"entry\"]")
      entries.each do |entry|
        load_into_db(entry)
      end
    end

    def load_into_db(entry)
      cve = Cve.new

      entry.children.each do |child|
        case child.name
        when "cve-id"
          cve.id = child.content
        when "summary"
          cve.summary = child.content
        when "published-datetime"
          cve.published = Time::Format::ISO_8601_DATE_TIME.parse(child.content)
        when "last-modified-datetime"
          cve.last_modified = Time::Format::ISO_8601_DATE_TIME.parse(child.content)
        when "cwe"
          cve.cwe_id = child["id"]
        end
      end
      begin
        VULNDB.exec("INSERT INTO cves (id, summary, cwe_id, published, last_modified) VALUES (?, ?, ?, ?, ?)", cve.id, cve.summary, cve.cwe_id, cve.published, cve.last_modified)
      rescue e : SQLite3::Exception
        # This exception handler intentionally left blank
      end
    end
  end
end
