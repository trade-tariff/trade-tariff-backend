class FullChemicalPopulatorService
  CSV_FILE = Rails.root.join('db/full_chemicals.csv')

  def call
    FullChemical.unrestrict_primary_key

    full_chemicals.each_slice(5000) do |values|
      FullChemical.dataset.insert_conflict(
        constraint: :full_chemicals_pkey,
        update: {
          cn_code: Sequel[:excluded][:cn_code],
          cas_rn: Sequel[:excluded][:cas_rn],
          ec_number: Sequel[:excluded][:ec_number],
          un_number: Sequel[:excluded][:un_number],
          nomen: Sequel[:excluded][:nomen],
          name: Sequel[:excluded][:name],
          goods_nomenclature_item_id: Sequel[:excluded][:goods_nomenclature_item_id],
          producline_suffix: Sequel[:excluded][:producline_suffix],
          updated_at: Sequel[:excluded][:updated_at],
        },
      ).multi_insert(values)
    end

    FullChemical.restrict_primary_key
  end

  private

  # TODO: This should be pulled from the CUS SOAP API and maybe in a separate service.
  def full_chemicals
    csv_table.each_with_object([]) do |row, all_chemicals|
      values = row.to_hash
      goods_nomenclature = goods_nomenclatures[values[:cn_code]]

      values[:goods_nomenclature_sid] = goods_nomenclature&.goods_nomenclature_sid
      values[:goods_nomenclature_item_id] = goods_nomenclature&.goods_nomenclature_item_id
      values[:producline_suffix] = goods_nomenclature&.producline_suffix
      values[:created_at] = now
      values[:updated_at] = now

      all_chemicals << FullChemical.new(values)
    end
  end

  def goods_nomenclatures
    @goods_nomenclatures ||= TimeMachine.now do
      GoodsNomenclature
          .actual
          .where(goods_nomenclature_filter)
          .index_by { |gn| "#{gn.goods_nomenclature_item_id}-#{gn.producline_suffix}" }
    end
  end

  def goods_nomenclature_filter
    filters = cn_codes.map do |gnid, pls|
      "(goods_nomenclature_item_id = '#{gnid}' AND producline_suffix = '#{pls}')"
    end
    filters.join(' OR ')
  end

  def cn_codes
    Set.new.tap do |codes|
      csv_table.each do |row|
        goods_nomenclature_item_id, producline_suffix = row[1].split('-')
        codes.add([goods_nomenclature_item_id, producline_suffix])
      end
    end
  end

  def csv_table
    @csv_table ||= CSV.table(CSV_FILE, headers: true)
  end

  def now
    @now ||= Time.zone.now
  end
end
