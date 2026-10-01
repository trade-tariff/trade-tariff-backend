require 'csv'

module SearchReferences
  # Imports FPO extra references from a CSV of "Goods Description,Commodity Code" rows.
  #
  # Each row becomes a SearchReference with usage 'fpo'. These references are used
  # only to train the FPO classifier and are hidden from public search.
  class FpoCsvImporter
    DESCRIPTION_HEADER = 'Goods Description'.freeze
    CODE_HEADER = 'Commodity Code'.freeze
    VALID_CODE = /\A(\d{8}|\d{10})\z/
    FORMULA_PREFIXES = %w[= + - @].freeze
    DEFAULT_WHODUNNIT = 'fpo_csv_import'.freeze

    Row = Data.define(:line, :title, :code)

    Result = Data.define(:created, :existing, :duplicate, :invalid, :unresolved_code, :failed) do
      def summary
        [
          "created: #{created.size}",
          "already present: #{existing.size}",
          "duplicate rows: #{duplicate.size}",
          "invalid row: #{invalid.size}",
          "unresolved code: #{unresolved_code.size}",
          "failed validation: #{failed.size}",
        ].join(', ')
      end
    end

    def self.call(csv_path, dry_run: false, output: $stdout, whodunnit: DEFAULT_WHODUNNIT)
      new(csv_path, dry_run:, output:, whodunnit:).call
    end

    def initialize(csv_path, dry_run: false, output: $stdout, whodunnit: DEFAULT_WHODUNNIT)
      @csv_path = csv_path
      @dry_run = dry_run
      @output = output
      @whodunnit = whodunnit.presence || DEFAULT_WHODUNNIT
      @outcomes = Hash.new { |hash, key| hash[key] = [] }
      @seen = Set.new
      @goods_nomenclatures = {}
    end

    def call
      raise ArgumentError, "CSV not found at #{@csv_path}" unless File.exist?(@csv_path)

      # Paper trail versions take their author from TradeTariffRequest.whodunnit.
      TradeTariffRequest.set(whodunnit: @whodunnit) do
        SearchReference.db.transaction(rollback: @dry_run ? :always : nil) do
          TimeMachine.now do
            each_row { |row| import(row) }
          end
        end
      end

      result.tap { |outcome| report(outcome) }
    end

  private

    def each_row
      CSV.foreach(@csv_path, headers: true, encoding: 'bom|utf-8').with_index(2) do |csv_row, line|
        yield Row.new(
          line:,
          title: normalise_title(csv_row[DESCRIPTION_HEADER]),
          code: csv_row[CODE_HEADER].to_s.strip,
        )
      end
    end

    def import(row)
      return record(:invalid, row) if row.title.blank? || !row.code.match?(VALID_CODE)

      goods_nomenclature_item_id = row.code.ljust(10, '0')
      return record(:duplicate, row) unless @seen.add?([row.title, goods_nomenclature_item_id])

      goods_nomenclature = find_goods_nomenclature(goods_nomenclature_item_id)
      return record(:unresolved_code, row) if goods_nomenclature.nil?
      return record(:existing, row) if already_present?(row.title, goods_nomenclature)

      search_reference = SearchReference.new(
        title: row.title,
        usage: SearchReference::FPO_USAGE,
        referenced: goods_nomenclature,
      )

      search_reference.save ? record(:created, row) : record(:failed, row, search_reference.errors.full_messages.join('; '))
    end

    def find_goods_nomenclature(goods_nomenclature_item_id)
      @goods_nomenclatures.fetch(goods_nomenclature_item_id) do
        @goods_nomenclatures[goods_nomenclature_item_id] =
          GoodsNomenclature
            .actual
            .with_leaf_column
            .non_hidden
            .non_grouping
            .by_code(goods_nomenclature_item_id)
            .first
      end
    end

    # A matching 'search' reference is already used by FPO training, so an 'fpo' copy is not needed.
    def already_present?(title, goods_nomenclature)
      SearchReference
        .where(goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid)
        .where(Sequel.function(:lower, :title) => title)
        .any?
    end

    def normalise_title(title)
      normalised = title.to_s.squish.downcase
      FORMULA_PREFIXES.any? { |prefix| normalised.start_with?(prefix) } ? "'#{normalised}" : normalised
    end

    def record(outcome, row, reason = nil)
      @outcomes[outcome] << [row, reason]
    end

    def result
      Result.new(**Result.members.index_with { |member| @outcomes[member] })
    end

    def report(outcome)
      @output.puts "#{@dry_run ? '[DRY RUN] ' : ''}FPO search references import: #{outcome.summary}"

      %i[existing invalid unresolved_code failed].each do |member|
        entries = outcome.public_send(member)
        next if entries.empty?

        @output.puts "#{member.to_s.humanize}:"
        entries.each do |row, reason|
          @output.puts "  line #{row.line}: #{row.title.inspect} -> #{row.code.inspect}#{" (#{reason})" if reason}"
        end
      end
    end
  end
end
