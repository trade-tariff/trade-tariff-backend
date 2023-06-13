module TenDigitGoodsNomenclature
  extend ActiveSupport::Concern

  included do
    plugin :oplog, primary_key: :goods_nomenclature_sid

    include Declarable

    set_dataset filter('goods_nomenclatures.goods_nomenclature_item_id NOT LIKE ?', '____000000')
      .order(Sequel.asc(:goods_nomenclatures__goods_nomenclature_item_id),
             Sequel.asc(:goods_nomenclatures__producline_suffix),
             Sequel.asc(:goods_nomenclatures__goods_nomenclature_sid))

    set_primary_key [:goods_nomenclature_sid]

    one_to_one :heading, primary_key: :heading_short_code, key: :heading_short_code, foreign_key: :heading_short_code do |ds|
      ds.with_actual(Heading)
        .filter(producline_suffix: GoodsNomenclatureIndent::NON_GROUPING_PRODUCTLINE_SUFFIX)
    end

    one_to_one :chapter, primary_key: :chapter_short_code, key: :chapter_short_code, foreign_key: :chapter_short_code do |ds|
      ds.with_actual(Chapter)
    end

    one_to_many :overview_measures, key: {}, primary_key: {}, class_name: 'Measure', dataset: lambda {
      measures_dataset.overview
    }

    delegate :section, :section_id, to: :chapter, allow_nil: true

    dataset_module do
      def by_code(code = '')
        filter(goods_nomenclatures__goods_nomenclature_item_id: code.to_s.first(10))
      end

      def by_productline_suffix(productline_suffix)
        filter(producline_suffix: productline_suffix)
      end

      def declarable
        filter(producline_suffix: GoodsNomenclatureIndent::NON_GROUPING_PRODUCTLINE_SUFFIX)
      end
    end

    # See oplog sequel plugin
    def operation=(operation)
      self[:operation] = operation.to_s.first.upcase
    end

    def ancestors
      # TODO: we need to create more efficient and unambiguous way to get ancestors
      # because getting Commodities with goods_nomenclature_item_id LIKE 'something'
      # can fetch Commodities not from ancestors tree.
      Commodity.select(Sequel.expr(:goods_nomenclatures).*)
        .eager(:goods_nomenclature_indents,
               :goods_nomenclature_descriptions)
        .join_table(:inner,
                    GoodsNomenclatureIndent
        .select(:goods_nomenclature_indents__goods_nomenclature_sid,
                :goods_nomenclature_indents__goods_nomenclature_item_id,
                :goods_nomenclature_indents__number_indents)
        .with_actual(GoodsNomenclature)
        .join(:goods_nomenclatures, goods_nomenclature_indents__goods_nomenclature_sid: :goods_nomenclatures__goods_nomenclature_sid)
        .where('goods_nomenclature_indents.goods_nomenclature_item_id LIKE ?', heading_id)
        .where('goods_nomenclature_indents.goods_nomenclature_item_id <= ?', goods_nomenclature_item_id)
        .order(Sequel.desc(:goods_nomenclature_indents__validity_start_date),
               Sequel.desc(:goods_nomenclature_indents__goods_nomenclature_item_id))
        .from_self
        .group(:goods_nomenclature_sid, :goods_nomenclature_item_id, :number_indents)
        .from_self
        .where('number_indents < ?', goods_nomenclature_indent.number_indents),
                    t1__goods_nomenclature_sid: :goods_nomenclatures__goods_nomenclature_sid,
                    t1__goods_nomenclature_item_id: :goods_nomenclatures__goods_nomenclature_item_id)
        .order(Sequel.desc(:goods_nomenclatures__goods_nomenclature_item_id))
        .all
        .group_by(&:number_indents)
        .map(&:last)
        .map(&:first)
        .reverse
        .sort_by(&:number_indents)
        .select { |a| a.number_indents < goods_nomenclature_indent.number_indents }
    end

    def declarable?
      cache_key = "commodity-#{goods_nomenclature_sid}-#{point_in_time&.to_date&.iso8601}-is-declarable?"

      Rails.cache.fetch(cache_key) do
        non_grouping? && children.none?
      end
    end

    def uptree
      @uptree ||= [ancestors, heading, chapter, self].flatten.compact
    end

    def children
      @children ||= begin
        mapper = GoodsNomenclatureMapper.new(preloaded_children.presence || load_children)

        mapped = mapper.all.detect do |goods_nomenclature|
          goods_nomenclature.goods_nomenclature_sid == goods_nomenclature_sid
        end

        mapped.try(:children) || []
      end
    end

    def to_param
      code
    end

    def code
      goods_nomenclature_item_id
    end

    def short_code
      if ns_declarable?
        goods_nomenclature_item_id
      else
        case goods_nomenclature_item_id
        when /^\d+0000$/ then harmonised_system_code
        when /^\d+00$/ then combined_nomenclature_code
        else taric_code
        end
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

    def traverse_children(&block)
      yield self

      children.each { |child| child.traverse_children(&block) }
    end

    def goods_nomenclature_class
      ns_declarable? ? 'Commodity' : 'Subheading'
    end

    def to_admin_param
      "#{goods_nomenclature_item_id}-#{producline_suffix}"
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

    def load_children
      heading.commodities_dataset
        .eager(:goods_nomenclature_indents, :goods_nomenclature_descriptions)
        .all
    end

    def preloaded_children
      Thread.current[:heading_commodities].try(:fetch, heading_short_code, {})
    end
  end
end
