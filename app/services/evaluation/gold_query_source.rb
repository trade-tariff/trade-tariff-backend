module Evaluation
  # One thing a set of gold queries can be generated from: a real ATaR ruling or a
  # synthetic ATaR (written by HMRC analysts). It carries everything
  # GoldQueryGenerator needs, so the generator does not care which kind it was given.
  #
  # - source_id is the ruling's ref for an ATaR and the record's id (as a string) for
  #   a synthetic ATaR.
  # - text is what the model reads. oracle_text is the copy stored on each gold query,
  #   and later read by the eval app's simulated trader. Today they are the same text.
  # - real_user_search is only present for a synthetic ATaR.
  # - expected_code keeps the granularity the source published (an ATaR can classify to
  #   6, 8 or 10 digits). It is never right-padded.
  GoldQuerySource = Data.define(
    :source_type,
    :source_id,
    :text,
    :real_user_search,
    :expected_code,
    :expected_description,
    :oracle_text,
  ) do
    extend HtmlToPlainText

    class << self
      # Finds the source again from the two values a background job carries.
      # Returns nil when the source no longer exists.
      def for(source_type:, source_id:)
        case source_type
        when 'atar'
          ruling = TariffKnowledge::PublicAtarRuling.by_ref(source_id).first
          from_public_atar_ruling(ruling) if ruling
        when 'synthetic_atar'
          record = TariffKnowledge::SyntheticAtar[source_id.to_i]
          from_synthetic_atar(record) if record
        end
      end

      def from_public_atar_ruling(ruling)
        text = ruling.description.presence || ruling.justification.to_s

        new(
          source_type: 'atar',
          source_id: ruling.ref,
          text:,
          real_user_search: nil,
          expected_code: ruling.commodity_code,
          expected_description: commodity_description(ruling.goods_nomenclature_item_id),
          oracle_text: text,
        )
      end

      def from_synthetic_atar(synthetic_atar)
        new(
          source_type: 'synthetic_atar',
          source_id: synthetic_atar.id.to_s,
          text: synthetic_atar.description,
          real_user_search: synthetic_atar.real_user_search,
          expected_code: synthetic_atar.goods_nomenclature_item_id,
          expected_description: commodity_description(synthetic_atar.goods_nomenclature_item_id),
          oracle_text: synthetic_atar.description,
        )
      end

    private

      # Multiple description periods can exist for the same code (one per historical
      # revision), so order by period sid descending to deterministically pick the
      # most recent one — same pattern as CachedCommodityDescriptionService's
      # load_latest_formatted_descriptions.
      #
      # Deliberately not filtered to goods_nomenclatures.validity_end_date IS NULL (i.e.
      # currently-valid codes only): ATaR rulings can reference historical/superseded
      # commodity codes, and the gold set should still capture that code's description as
      # it was, rather than nothing.
      def commodity_description(goods_nomenclature_item_id)
        description = GoodsNomenclatureDescription
          .where(goods_nomenclature_item_id:)
          .order(Sequel.desc(:goods_nomenclature_description_period_sid))
          .first
        return unless description

        html_to_plain_text(description.formatted_description.to_s)
      end
    end
  end
end
