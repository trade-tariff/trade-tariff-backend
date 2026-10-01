module Evaluation
  # One source item of a gold query set (an ATaR ruling or a synthetic ATaR) together with
  # the three gold queries written for it, one per persona.
  #
  # The database holds three separate rows, but an operator looks at, edits and deletes
  # them as one thing. This class does that grouping, and it holds the edit rules, so the
  # controller stays thin. The rules are:
  #
  # - The expected code is one fact about the item, so an edit to it is saved to all three
  #   rows.
  # - A query and its notes belong to one persona, so they are saved to that persona's row.
  # - Everything is saved or nothing is: if one field is invalid, no row changes.
  # - A row is only saved if something on it changed, so history only records real edits.
  class GoldQueryItem
    PERSONAS = GoldQueryGenerator::PERSONA_FOR_TIER.values.freeze
    # ATaR rulings can classify to 6, 8 or 10 digits (see EvaluationGoldQuery), and
    # synthetic ATaRs always have 10, so those are the three lengths accepted.
    CODE_FORMAT = /\A(\d{6}|\d{8}|\d{10})\z/
    CODE_ERROR = 'must be 6, 8 or 10 digits'.freeze

    attr_reader :rows, :errors

    class << self
      # Every item of the set. A set holds at most EvaluationGoldQuerySet::MAX_SIZE items
      # (three rows each), so loading them all in one query is cheap.
      #
      # Ordered by source type, then by source id as a number (shorter ids first), because
      # a plain text sort would put synthetic ATaR 10 before 9.
      def for_set(gold_query_set)
        rows = gold_query_set
          .evaluation_gold_queries_dataset
          .order(:source_type, Sequel.function(:length, :source_id), :source_id, :persona)
          .all

        rows.group_by { |row| [row.source_type, row.source_id] }.values.map { |group| new(group) }
      end

      # An item id is "<source type>-<source id>", for example "synthetic_atar-12". Neither
      # source type contains a dash, so the first dash always splits the two.
      def find(gold_query_set, item_id)
        source_type, _dash, source_id = item_id.to_s.partition('-')
        rows = gold_query_set.evaluation_gold_queries_dataset.where(source_type:, source_id:).order(:persona).all
        raise Sequel::NoMatchingRow, item_id if rows.empty?

        new(rows)
      end
    end

    def initialize(rows)
      @rows = rows
      @errors = Sequel::Model::Errors.new
    end

    def id = "#{source_type}-#{source_id}"
    def gold_query_set_id = rows.first.set_id
    def source_type = rows.first.source_type
    def source_id = rows.first.source_id
    def expected_code = rows.first.expected_code
    def oracle_text = rows.first.oracle_text

    def query_for(persona) = row_for(persona)&.query
    def notes_for(persona) = row_for(persona)&.notes

    # What the trader typed, for an item made from a synthetic ATaR. It is read from that
    # record, not copied onto the gold queries, so it is nil if the record was deleted.
    # One lookup per item is fine because a page holds a few dozen items at most.
    def real_user_search
      return @real_user_search if defined?(@real_user_search)

      @real_user_search = (TariffKnowledge::SyntheticAtar.where(id: source_id.to_i).get(:real_user_search) if source_type == 'synthetic_atar')
    end

    # attributes may hold :expected_code and, for each persona, :<persona>_query and
    # :<persona>_notes, for example :emu_generic_query. A key that is missing leaves that
    # value as it is. Returns true when saved, or false with the reasons in #errors.
    def update(attributes)
      @errors = Sequel::Model::Errors.new
      assign(attributes)
      validate
      return false if errors.any?

      EvaluationGoldQuery.db.transaction { rows.each(&:save_changes) }
      true
    end

    # Each row's own after-destroy hook writes a 'destroy' history entry.
    def destroy
      EvaluationGoldQuery.db.transaction { rows.each(&:destroy) }
    end

    # The history of all three rows together, newest first.
    def versions
      Version.where(item_type: EvaluationGoldQuery.name, item_id: rows.map { |row| row.id.to_s }).order(Sequel.desc(:id))
    end

  private

    def row_for(persona)
      rows.find { |row| row.persona == persona }
    end

    def assign(attributes)
      rows.each { |row| row.expected_code = attributes[:expected_code].to_s.strip } if attributes.key?(:expected_code)

      rows.each do |row|
        row.query = attributes[:"#{row.persona}_query"].to_s.strip if attributes.key?(:"#{row.persona}_query")
        row.notes = attributes[:"#{row.persona}_notes"].to_s.strip.presence if attributes.key?(:"#{row.persona}_notes")
      end
    end

    def validate
      rows.each do |row|
        next if row.valid?

        row.errors.each do |column, messages|
          messages.each { |message| add_error(error_attribute(row, column), message) }
        end
      end

      validate_expected_code_format
    end

    # Only checked when the operator changed the code, so an old row with an unusual code
    # can still have its queries corrected.
    def validate_expected_code_format
      return unless rows.first.changed_columns.include?(:expected_code)
      return if expected_code.blank? || expected_code.match?(CODE_FORMAT)

      add_error(:expected_code, CODE_ERROR)
    end

    # A query error is named after its persona, as the API names that field. The expected
    # code is the same on all three rows, so it is reported once.
    def error_attribute(row, column)
      %i[query notes].include?(column) ? :"#{row.persona}_#{column}" : column
    end

    def add_error(attribute, message)
      errors.add(attribute, message) unless Array(errors[attribute]).include?(message)
    end
  end
end
