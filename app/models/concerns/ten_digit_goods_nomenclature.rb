module TenDigitGoodsNomenclature
  extend ActiveSupport::Concern

  included do
    plugin :oplog, primary_key: :goods_nomenclature_sid, materialized: true

    set_dataset filter('goods_nomenclatures.goods_nomenclature_item_id NOT LIKE ?', '____000000')
      .order(Sequel.asc(:goods_nomenclatures__goods_nomenclature_item_id),
             Sequel.asc(:goods_nomenclatures__producline_suffix),
             Sequel.asc(:goods_nomenclatures__goods_nomenclature_sid))

    set_primary_key [:goods_nomenclature_sid]

    one_to_one :heading,
               primary_key: :heading_short_code,
               key: :heading_short_code,
               foreign_key: :heading_short_code,
               graph_use_association_block: true do |ds|
      ds.with_actual(Heading).non_grouping
    end

    one_to_one :chapter,
               primary_key: :chapter_short_code,
               key: :chapter_short_code,
               foreign_key: :chapter_short_code,
               graph_use_association_block: true do |ds|
      ds.with_actual(Chapter)
    end

    delegate :section, :section_id, to: :chapter, allow_nil: true

    dataset_module do
      def by_code(code = '')
        filter(goods_nomenclatures__goods_nomenclature_item_id: code.to_s.first(10))
      end

      def by_productline_suffix(productline_suffix)
        filter(producline_suffix: productline_suffix)
      end
    end

    # See oplog sequel plugin
    def operation=(operation)
      self[:operation] = operation.to_s.first.upcase
    end

    def to_param
      code
    end

    def code
      goods_nomenclature_item_id
    end

    def short_code
      if declarable?
        goods_nomenclature_item_id
      else
        specific_system_short_code
      end
    end

    def specific_system_short_code
      case goods_nomenclature_item_id
      when /^\d+0000$/ then harmonised_system_code
      when /^\d+00$/ then combined_nomenclature_code
      else taric_code
      end
    end

    def self.changes_for(depth = 0, conditions = {})
      operation_klass.select(
        Sequel.as(Sequel.cast_string('Commodity'), :model),
        :oid,
        :operation_date,
        :operation,
        Sequel.as(depth, :depth),
      ).where(conditions)
        .where(Sequel.~(operation_date: nil))
        .limit(TradeTariffBackend.change_count)
        .order(Sequel.desc(:operation_date, nulls: :last))
    end

    def changes(depth = 1)
      operation_klass.select(
        Sequel.as(Sequel.cast_string('GoodsNomenclature'), :model),
        :oid,
        :operation_date,
        :operation,
        Sequel.as(depth, :depth),
      ).where(pk_hash)
        .union(
          Measure.changes_for(
            depth + 1,
            Sequel.qualify(:measures_oplog, :goods_nomenclature_item_id) => goods_nomenclature_item_id,
          ),
        )
            .from_self
            .where(Sequel.~(operation_date: nil))
            .tap! { |criteria|
              # if Commodity did not come from initial seed, filter by its
              # create/update date
              criteria.where { |o| o.>=(:operation_date, operation_date) } if operation_date.present?
            }
              .limit(TradeTariffBackend.change_count)
              .order(Sequel.desc(:operation_date, nulls: :last), Sequel.desc(:depth))
    end

    def goods_nomenclature_class
      declarable? ? 'Commodity' : 'Subheading'
    end

    def to_admin_param
      goods_nomenclature_item_id
    end

    private

    def harmonised_system_code
      goods_nomenclature_item_id.first(6)
    end

    def combined_nomenclature_code
      goods_nomenclature_item_id.first(8)
    end

    def taric_code
      goods_nomenclature_item_id
    end
  end
end
