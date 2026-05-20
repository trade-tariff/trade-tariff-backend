# frozen_string_literal: true

# Target the MyOTT tariff-change query shapes:
#
# - user notification joins and change lookups filter by operation_date and
#   goods_nomenclature_sid.
# - commodity and description change panels add a type-specific action filter.
# - grouped measure changes add JSONB metadata criteria, so a smaller btree
#   partial index lets PostgreSQL narrow by date/SID before applying metadata.

Sequel.migration do
  up do
    next unless TradeTariffBackend.uk?

    run <<-SQL
      CREATE INDEX IF NOT EXISTS tariff_changes_operation_date_goods_nomenclature_sid_index
        ON tariff_changes (operation_date, goods_nomenclature_sid);

      CREATE INDEX IF NOT EXISTS tariff_changes_commodity_date_sid_action_index
        ON tariff_changes (operation_date, goods_nomenclature_sid, action)
        WHERE type = 'Commodity';

      CREATE INDEX IF NOT EXISTS tariff_changes_commodity_description_date_sid_action_index
        ON tariff_changes (operation_date, goods_nomenclature_sid, action)
        WHERE type = 'GoodsNomenclatureDescription';

      CREATE INDEX IF NOT EXISTS tariff_changes_measure_date_sid_index
        ON tariff_changes (operation_date, goods_nomenclature_sid)
        WHERE type = 'Measure';
    SQL
  end

  down do
    next unless TradeTariffBackend.uk?

    run <<-SQL
      DROP INDEX IF EXISTS tariff_changes_measure_date_sid_index;
      DROP INDEX IF EXISTS tariff_changes_commodity_description_date_sid_action_index;
      DROP INDEX IF EXISTS tariff_changes_commodity_date_sid_action_index;
      DROP INDEX IF EXISTS tariff_changes_operation_date_goods_nomenclature_sid_index;
    SQL
  end
end
