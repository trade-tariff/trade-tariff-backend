module VatGuidance
  class HmrcPocArtifactWriter
    def initialize(json_path, html_path, artifact)
      @json_path = Pathname.new(json_path)
      @html_path = Pathname.new(html_path)
      @artifact = artifact
    end

    def call
      expected_hash = QuestionJourneyArtifactBuilder.content_sha256(artifact)
      raise ArgumentError, 'HMRC PoC artifact content hash is invalid' unless artifact['content_sha256'] == expected_hash

      json = "#{JSON.pretty_generate(artifact)}\n"
      html = HmrcPocRenderer.new(artifact).call
      FileUtils.mkdir_p(json_path.dirname)
      FileUtils.mkdir_p(html_path.dirname)
      previous_json = existing_file(json_path)
      previous_html = existing_file(html_path)
      publish_pair(json, html, previous_json, previous_html)
    end

  private

    attr_reader :json_path, :html_path, :artifact

    def publish_pair(json, html, previous_json, previous_html)
      File.atomic_write(html_path) { |file| file.write(html) }
      File.atomic_write(json_path) { |file| file.write(json) }
    rescue StandardError
      restore(html_path, previous_html)
      restore(json_path, previous_json)
      raise
    end

    def existing_file(path)
      File.binread(path) if path.file?
    end

    def restore(path, content)
      if content
        File.atomic_write(path) { |file| file.write(content) }
      elsif path.file?
        FileUtils.rm_f(path)
      end
    end
  end
end
