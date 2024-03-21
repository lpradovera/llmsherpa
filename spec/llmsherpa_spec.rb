# frozen_string_literal: true

RSpec.describe Llmsherpa do
  it "has a version number" do
    expect(Llmsherpa::VERSION).not_to be nil
  end

  describe Llmsherpa::Document do
    let(:json) { JSON.parse(File.read("#{RSPEC_ROOT}/docs/test_file.json")) }
    let(:doc) { Llmsherpa::Document.new(json.dig("return_dict", "result", "blocks")) }

    it "does something useful" do
      expect(doc.sections.size).to be 4
      expect(doc.sections[3].to_text).to eq "Third Paragraph"
    end
  end

  describe Llmsherpa::LayoutPDFReader do
    let(:parser_api_url) { "http://localhost:5010/api/parseDocument\?renderFormat\=all" }
    let(:pdf_reader) { Llmsherpa::LayoutPDFReader.new(parser_api_url) }

    it "parses a PDF" do
      VCR.use_cassette("parse_local_pdf") do
        pdf_path = "#{RSPEC_ROOT}/docs/test_file.pdf"
        doc = pdf_reader.read_pdf(pdf_path)
        expect(doc.chunks.size).to be 5
        expect(doc.chunks[2].to_text).to start_with "Column A"
      end
    end

    it "downloads a remote PDF and parses it" do
      VCR.use_cassette("remote_pdf") do
        pdf_url = "https://www.orimi.com/pdf-test.pdf"
        doc = pdf_reader.read_pdf(pdf_url)
        expect(doc.chunks.size).to be 2
        expect(doc.chunks[0].to_text).to start_with "Congratulations"
      end
    end
  end
end
