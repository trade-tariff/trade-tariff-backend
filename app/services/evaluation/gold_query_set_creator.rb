module Evaluation
  # Creates a gold query set and starts generating it in the background.
  #
  # The caller (an admin API request or the rake task) only waits for the cheap part:
  # checking the input, picking the source items at random and queueing one job. The
  # slow part, asking the model for each item, runs in Sidekiq.
  #
  #   set = Evaluation::GoldQuerySetCreator.call(name: 'Set A', requested_size: 100, atar_percentage: 20, created_by: 'user-123')
  #   set.errors.empty? # false when nothing was created, and the errors say why
  class GoldQuerySetCreator
    def self.call(...) = new(...).call

    def initialize(name:, requested_size:, atar_percentage:, created_by:)
      @attributes = { name:, requested_size:, atar_percentage:, created_by: }
    end

    def call
      set = EvaluationGoldQuerySet.new(@attributes.merge(planned_count: 0, status: 'generating'))
      return set unless set.valid?

      items = sample(set)
      if items.empty?
        set.errors.add(:requested_size, 'cannot be met, because there are no ATaR rulings or synthetic ATaRs to generate from')
        return set
      end

      set.planned_count = items.size
      set.save
      enqueue(set, items)
      set
    end

  private

    # round(size x percentage / 100) items come from the real ATaR rulings and the rest from
    # the synthetic ATaRs. If a source has fewer items than asked for, all of them are taken
    # and planned_count records the shortfall. The other source does not top it up.
    def sample(set)
      atar_count = (set.requested_size * set.atar_percentage / 100.0).round
      synthetic_count = set.requested_size - atar_count

      atars = random_values(TariffKnowledge::PublicAtarRuling, :ref, atar_count).map { |ref| ['atar', ref] }
      synthetic_atars = random_values(TariffKnowledge::SyntheticAtar, :id, synthetic_count).map { |id| ['synthetic_atar', id.to_s] }

      atars + synthetic_atars
    end

    # A random sample without replacement: each row can be picked at most once.
    def random_values(model, column, count)
      return [] if count.zero?

      model.order(Sequel.function(:random)).limit(count).select_map(column)
    end

    # Queued only after the set is saved, so the job can never run before the set exists.
    # If queueing fails nothing will ever finish the set, so it is removed again instead of
    # being left in "generating" for ever.
    def enqueue(set, items)
      GenerateGoldQuerySetWorker.perform_async(set.id, items)
    rescue StandardError
      set.destroy
      raise
    end
  end
end
