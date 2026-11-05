module Evaluation
  # Creates a synthetic input set and its items in one request. Unlike GoldQuerySetCreator there is
  # no LLM call per item -- sampling synthetic ATaRs verbatim is cheap, so the whole thing finishes
  # synchronously, with no background job and no "generating" status.
  #
  # Each item searches with the real user search, the words a trader actually typed. The analyst's
  # full product description is kept separately as oracle_text, which only the simulated trader reads
  # to answer clarifying questions. Searching with the description instead would hand search the
  # answers to the questions it should ask, in wording close to the tariff's own.
  #
  #   set = Evaluation::SyntheticInputSetCreator.call(name: 'Set A', requested_size: 100, created_by: 'user-123')
  #   set.errors.empty? # false when nothing was created, and the errors say why
  class SyntheticInputSetCreator
    def self.call(...) = new(...).call

    def initialize(name:, requested_size:, created_by:)
      @attributes = { name:, requested_size:, created_by: }
    end

    def call
      set = EvaluationSyntheticInputSet.new(@attributes.merge(actual_size: 0))
      return set unless set.valid?

      synthetic_atars = sample(set.requested_size)
      if synthetic_atars.empty?
        set.errors.add(:requested_size, 'cannot be met, because there are no synthetic ATaRs to sample from')
        return set
      end

      set.actual_size = synthetic_atars.size
      EvaluationSyntheticInputSet.db.transaction do
        set.save
        insert_items(set, synthetic_atars)
      end
      set
    end

  private

    # A random sample without replacement: each synthetic ATaR can be picked at most once. LIMIT
    # alone handles the "fewer exist than requested_size" case -- it simply returns fewer rows.
    def sample(count)
      return [] if count.to_i <= 0

      TariffKnowledge::SyntheticAtar.order(Sequel.function(:random)).limit(count.to_i).all
    end

    def insert_items(set, synthetic_atars)
      rows = synthetic_atars.map do |synthetic_atar|
        {
          set_id: set.id,
          synthetic_atar_id: synthetic_atar.id,
          query: synthetic_atar.real_user_search,
          oracle_text: synthetic_atar.description,
          expected_code: synthetic_atar.goods_nomenclature_item_id,
        }
      end
      EvaluationSyntheticInputSetItem.multi_insert(rows)
    end
  end
end
