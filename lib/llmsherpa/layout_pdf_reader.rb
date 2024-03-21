# frozen_string_literal: true

require "net/http"
require "uri"
require "json"
require "open-uri"
require "tempfile"

module Llmsherpa
  class LayoutPDFReader
    # Reads PDF content and understands hierarchical layout of the document sections and structural components
    def initialize(parser_api_url)
      @parser_api_url = parser_api_url
    end

    def read_pdf(path_or_url, contents = nil)
      pdf_file = if contents
                   [path_or_url, contents, "application/pdf"]
                 else
                   is_url = %w[http https].include?(URI.parse(path_or_url).scheme)
                   if is_url
                     _download_pdf(path_or_url)
                   else
                     file_name = path_or_url
                     file_data = nil # no need to read the file here
                     [file_name, file_data, "application/pdf"]
                   end
                 end

      parser_response = _parse_pdf(pdf_file)
      response_json = JSON.parse(parser_response.body)
      blocks = response_json["return_dict"]["result"]["blocks"]
      Document.new(blocks)
    end

    private

    def _download_pdf(pdf_url)
      user_agent = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36"
      download_uri = URI(pdf_url)
      download_request = Net::HTTP::Get.new(download_uri)
      download_request["User-Agent"] = user_agent
      download_response = Net::HTTP.start(download_uri.hostname, download_uri.port,
                                          use_ssl: download_uri.scheme == "https") do |http|
        http.request(download_request)
      end
      file_name = File.basename(download_uri.path)
      temp_file = Tempfile.new(file_name)
      temp_file.write(download_response.body)
      pdf_file = [temp_file.path, "", "application/pdf"] if download_response.code == "200"
      pdf_file
    end

    def _parse_pdf(pdf_file)
      uri = URI(@parser_api_url)
      request = Net::HTTP::Post.new(uri)
      request.set_form({ "file" => File.open(pdf_file[0]) }, "multipart/form-data")
      Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(request)
      end
    end
  end
end
