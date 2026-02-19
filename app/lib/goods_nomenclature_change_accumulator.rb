# Collects goods nomenclature changes during a CDS/TARIC import cycle and
# dispatches them as batched Sidekiq jobs once the import completes.
#
# Callbacks on GN-family models (origin, successor, indent, description, and
# the GN itself) call .push! as records are created/updated. The synchronizer
# worker calls .flush! after applying updates and refreshing materialized
# views. Flush groups changes by chapter and enqueues one
# GoodsNomenclatureChangeWorker per affected chapter.
module GoodsNomenclatureChangeAccumulator
  CHANGE_TYPES = %i[moved structure_changed description_changed].freeze

  Change = Data.define(:sid, :change_type, :item_id) do
    def chapter_code
      item_id[0, 2]
    end
  end

  class << self
    def push!(sid:, change_type:, item_id:)
      raise ArgumentError, "Unknown change type: #{change_type}" unless CHANGE_TYPES.include?(change_type)

      mutex.synchronize do
        changes << Change.new(sid:, change_type:, item_id:)
      end
    end

    def flush!
      batch = mutex.synchronize do
        current = changes.dup
        changes.clear
        current
      end

      return if batch.empty?

      grouped = batch.group_by(&:chapter_code)

      grouped.each do |chapter_code, chapter_changes|
        sid_change_map = chapter_changes.each_with_object({}) do |change, map|
          map[change.sid] ||= []
          map[change.sid] << change.change_type unless map[change.sid].include?(change.change_type)
        end

        GoodsNomenclatureChangeWorker.perform_async(chapter_code, sid_change_map.transform_keys(&:to_s))
      end
    end

    def pending_count
      mutex.synchronize { changes.size }
    end

    def reset!
      mutex.synchronize { changes.clear }
    end

    private

    def changes
      @changes ||= []
    end

    def mutex
      @mutex ||= Mutex.new
    end
  end
end
