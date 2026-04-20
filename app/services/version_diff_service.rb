require 'diff/lcs'

class VersionDiffService
  SKIP_FIELDS = {
    'GoodsNomenclatureLabel' => %w[
      goods_nomenclature_sid
      goods_nomenclature_item_id
      producline_suffix
      goods_nomenclature_type
      created_at
      updated_at
      context_hash
      description_score
      synonym_scores
      colloquial_term_scores
      labels
    ].freeze,
    'GoodsNomenclatureSelfText' => %w[
      goods_nomenclature_sid
      goods_nomenclature_item_id
      embedding
      eu_embedding
      search_embedding
      search_embedding_stale
      created_at
      updated_at
      context_hash
      similarity_score
      coherence_score
      generated_at
    ].freeze,
    'AdminConfiguration' => %w[
      id
      name
      config_type
      area
      value
      created_at
      updated_at
    ].freeze,
    'DescriptionIntercept' => %w[
      id
      created_at
      updated_at
    ].freeze,
    'GoodsNomenclatureIntercept' => %w[
      goods_nomenclature_sid
      created_at
      updated_at
    ].freeze,
  }.freeze

  TEXT_THRESHOLD = 40

  def initialize(item_type, old_object, new_object)
    @item_type = item_type
    @old_object = old_object
    @new_object = new_object
  end

  def call
    return nil if @old_object.nil?

    skip = SKIP_FIELDS.fetch(@item_type, [])
    old_filtered = @old_object.except(*skip).merge(extract_virtual_fields(@old_object))
    new_filtered = @new_object.except(*skip).merge(extract_virtual_fields(@new_object))

    all_keys = (old_filtered.keys | new_filtered.keys)
    changes = {}

    all_keys.each do |key|
      old_val = old_filtered[key]
      new_val = new_filtered[key]

      next if old_val == new_val

      changes[key] = diff_values(old_val, new_val)
    end

    return nil if changes.empty?

    {
      'changed_fields' => changes.keys,
      'changes' => changes,
    }
  end

  private

  def extract_virtual_fields(obj)
    return {} unless @item_type == 'AdminConfiguration'

    value = obj['value']
    return { 'value' => value } unless value.is_a?(Hash)

    fields = {}
    fields['selected'] = value['selected'] if value.key?('selected')

    if value['sub_values'].is_a?(Hash)
      value['sub_values'].each do |k, v|
        fields[k] = v
      end
    end

    fields
  end

  def diff_values(old_val, new_val)
    if old_val.is_a?(Array) && new_val.is_a?(Array)
      array_diff(old_val, new_val)
    elsif text_diff?(old_val, new_val)
      text_diff(old_val.to_s, new_val.to_s)
    else
      simple_diff(old_val, new_val)
    end
  end

  def text_diff?(old_val, new_val)
    old_val.is_a?(String) && new_val.is_a?(String) &&
      (old_val.length > TEXT_THRESHOLD || new_val.length > TEXT_THRESHOLD)
  end

  def text_diff(old_str, new_str)
    old_words = old_str.split(/(\s+)/)
    new_words = new_str.split(/(\s+)/)

    sdiff = Diff::LCS.sdiff(old_words, new_words)
    ops = collapse_sdiff(sdiff)

    { 'type' => 'text', 'diff' => ops }
  end

  def collapse_sdiff(changes)
    result = []

    changes.each do |change|
      case change.action
      when '='
        append_op(result, 'equal', change.new_element)
      when '!'
        append_op(result, 'delete', change.old_element)
        append_op(result, 'insert', change.new_element)
      when '-'
        append_op(result, 'delete', change.old_element)
      when '+'
        append_op(result, 'insert', change.new_element)
      end
    end

    result
  end

  def append_op(result, operation, text)
    return if text.nil?

    if result.last && result.last['op'] == operation
      result.last['text'] += text
    else
      result << { 'op' => operation, 'text' => text }
    end
  end

  def array_diff(old_arr, new_arr)
    {
      'type' => 'array',
      'added' => new_arr - old_arr,
      'removed' => old_arr - new_arr,
      'unchanged' => old_arr & new_arr,
    }
  end

  def simple_diff(old_val, new_val)
    { 'type' => 'simple', 'old' => old_val, 'new' => new_val }
  end
end
