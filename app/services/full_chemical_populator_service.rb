class FullChemicalPopulatorService
  CSV_FILE = Rails.root.join('db/full_chemicals.csv')
  CHUNK_SIZE = 5000

  def call
    FullChemical.unrestrict_primary_key

    process_full_chemicals_in_chunks

    FullChemical.restrict_primary_key
  end

  private

  def process_full_chemicals_in_chunks
    chunk = []

    CSV.foreach(CSV_FILE, headers: true) do |row|
      chunk << row

      if chunk.size >= CHUNK_SIZE
        process_full_chemicals_chunk(chunk)
        chunk = []
      end
    end

    process_full_chemicals_chunk(chunk) unless chunk.empty?
  end

  def process_full_chemicals_chunk(chunk)
    full_chemicals = chunk.map do |row|
      values = row.to_hash

      goods_nomenclature = goods_nomenclatures[values['cn_code']]

      values[:goods_nomenclature_sid] = goods_nomenclature&.goods_nomenclature_sid
      values[:goods_nomenclature_item_id] = goods_nomenclature&.goods_nomenclature_item_id
      values[:producline_suffix] = goods_nomenclature&.producline_suffix
      values[:created_at] = now
      values[:updated_at] = now

      FullChemical.new(values)
    end

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
    ).multi_insert(full_chemicals)
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
      CSV.foreach(CSV_FILE, headers: true) do |row|
        goods_nomenclature_item_id, producline_suffix = row[1].split('-')
        codes.add([goods_nomenclature_item_id, producline_suffix])
      end
    end
  end

  def now
    @now ||= Time.zone.now
  end
end
