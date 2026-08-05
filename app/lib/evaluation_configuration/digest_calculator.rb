require 'digest'

module EvaluationConfiguration
  class DigestCalculator
    DIGEST_LENGTH = 16

    def self.call(effective_configuration)
      canonical = canonicalize(effective_configuration)
      ::Digest::SHA256.hexdigest(canonical.to_json)[0, DIGEST_LENGTH]
    end

    def self.canonicalize(value)
      case value
      when Hash
        value.keys.sort.index_with { |key| canonicalize(value[key]) }
      when Array
        value.map { |element| canonicalize(element) }
      else
        value
      end
    end
  end
end
