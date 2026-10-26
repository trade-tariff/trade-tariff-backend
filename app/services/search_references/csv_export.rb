module SearchReferences
  class CsvExport
    HEADINGS = [
      'Search reference ID',
      'Title',
      'Commodity code',
      'Product line suffix',
      'Referenced class',
      'Usage',
      'Label description',
      'Label synonyms',
      'Label colloquial terms',
      'Label known brands',
      'Label stale',
      'Label needs review',
      'Label approved',
      'Label manually edited',
      'Label expired',
    ].freeze

    def self.call
      CSV.generate do |csv|
        csv << HEADINGS
        rows.each { |row| csv << build_row(row) }
      end
    end

    def self.rows
      sr = Sequel[:search_references]
      lbl = Sequel[:goods_nomenclature_labels]

      SearchReference
        .left_join(:goods_nomenclature_labels, goods_nomenclature_sid: :goods_nomenclature_sid)
        .order(sr[:goods_nomenclature_item_id], sr[:productline_suffix], sr[:title], sr[:id])
        .select_map([
          sr[:id],
          sr[:title],
          sr[:goods_nomenclature_item_id],
          sr[:productline_suffix],
          sr[:referenced_class],
          sr[:usage],
          lbl[:description],
          lbl[:synonyms],
          lbl[:colloquial_terms],
          lbl[:known_brands],
          lbl[:stale],
          lbl[:needs_review],
          lbl[:approved],
          lbl[:manually_edited],
          lbl[:expired],
        ])
    end

    # Titles and label text come from users, so make them safe to open in a spreadsheet
    def self.build_row(row)
      id, title, code, suffix, referenced_class, usage, description, synonyms, terms, brands, *state = row
      escape = Api::Shared::CsvSerializer.method(:escape_formula)

      [
        id,
        escape.call(title),
        code,
        suffix,
        referenced_class,
        usage,
        escape.call(description),
        escape.call(synonyms.to_a.join('; ')),
        escape.call(terms.to_a.join('; ')),
        escape.call(brands.to_a.join('; ')),
        *state,
      ]
    end

    private_class_method :rows, :build_row
  end
end
