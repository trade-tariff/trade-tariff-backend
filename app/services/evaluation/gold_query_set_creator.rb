module Evaluation
  # Creates a gold query set and starts generating it in the background.
  #
  # The caller (an admin API request or the rake task) only waits for the cheap part:
  # checking the input, picking the source items at random and queueing one job. The
  # slow part, asking the model for each item, runs in Sidekiq.
  #
  #   set = Evaluation::GoldQuerySetCreator.call(name: 'Set A', requested_size: 100, created_by: 'user-123')
  #   set.errors.empty? # false when nothing was created, and the errors say why
  class GoldQuerySetCreator
    def self.call(...) = new(...).call

    def initialize(name:, requested_size:, created_by:)
      @attributes = { name:, requested_size:, created_by: }
    end

    def call
      set = EvaluationGoldQuerySet.new(@attributes.merge(planned_count: 0, status: 'generating'))
      return set unless set.valid?

      items = sample(set)
      if items.empty?
        set.errors.add(:requested_size, 'cannot be met, because there are no ATaR rulings to generate from')
        return set
      end

      set.planned_count = items.size
      set.save
      enqueue(set, items)
      set
    end

  private

    # Synthetic ATaRs no longer feed gold query set generation (AI-1448) -- every item now
    # comes from the real ATaR rulings only.
    def sample(set)
      random_values(TariffKnowledge::PublicAtarRuling, :ref, set.requested_size).map { |ref| ['atar', ref] }
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
