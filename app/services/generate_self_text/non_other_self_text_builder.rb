module GenerateSelfText
  class NonOtherSelfTextBuilder < BaseSelfTextBuilder
    private

    def select_segments(segments)
      segments.reject { |s| s[:node][:is_other] || s[:node][:goods_nomenclature_class] == 'Chapter' }
    end

    def generation_type = 'ai_non_other'
    def system_prompt_config_key = 'non_other_self_text_context'
    def model_config_key = 'non_other_self_text_model'
    def batch_size_config_key = 'non_other_self_text_batch_size'

    def segment_middle_fields(segment)
      eu_self_text = segment[:node][:eu_self_text]
      eu_self_text ? { eu_self_text: } : {}
    end

    def context_trailing_fields(segment)
      eu_self_text = segment[:node][:eu_self_text]
      eu_self_text ? { 'eu_self_text' => eu_self_text } : {}
    end
  end
end
