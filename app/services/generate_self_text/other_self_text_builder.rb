module GenerateSelfText
  class OtherSelfTextBuilder < BaseSelfTextBuilder
    OTHER_PATTERN = SegmentExtractor::OTHER_PATTERN

    private

    def select_segments(segments)
      segments.select { |s| s[:node][:is_other] }
    end

    def generation_type = 'ai'
    def system_prompt_config_key = 'other_self_text_context'
    def model_config_key = 'other_self_text_model'
    def batch_size_config_key = 'other_self_text_batch_size'

    def segment_middle_fields(segment)
      { siblings: segment[:siblings].map { |s| s[:description] } }
    end

    def context_middle_fields(segment)
      { 'siblings' => segment[:siblings].map { |s| s[:description] } }
    end
  end
end
