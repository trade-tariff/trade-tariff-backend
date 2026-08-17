require 'fileutils'
require 'json'
require 'tempfile'

module VatGuidance
  class QuestionJourneyArtifactWriter
    InvalidArtifact = Class.new(StandardError)

    def initialize(path, artifact)
      @path = Pathname.new(path)
      @artifact = artifact.deep_stringify_keys
    end

    def call
      invalid_reports = artifact.fetch('validation_reports').reject { |report| report.fetch('valid') }
      raise InvalidArtifact, invalid_message(invalid_reports) if invalid_reports.any?
      unless artifact['content_sha256'] == QuestionJourneyArtifactBuilder.content_sha256(artifact)
        raise InvalidArtifact, 'artifact content hash is invalid'
      end

      FileUtils.mkdir_p(path.dirname)
      Tempfile.create(['question-journeys-', '.json'], path.dirname) do |file|
        file.write("#{JSON.pretty_generate(artifact)}\n")
        file.flush
        file.fsync
        File.rename(file.path, path)
      end
      path
    end

  private

    attr_reader :path, :artifact

    def invalid_message(reports)
      details = reports.flat_map { |report| report.fetch('errors') }.join('; ')
      "question journey validation failed: #{details}"
    end
  end
end
