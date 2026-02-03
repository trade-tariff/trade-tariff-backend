module HeadingService
  class PrecacheService
    CACHE_TTL = 23.hours

    attr_reader :actual_date

    def initialize(date)
      @actual_date = date
    end

    def call
      TimeMachine.at(actual_date) do
        each_heading do |heading|
          write_heading(heading)

          heading.descendants.each do |subheading|
            next if subheading.declarable?

            write_subheading subheading
          end
        end
      end
    end

    private

    def each_heading
      Chapter.actual.non_hidden.all do |chapter|
        Chapter.actual
               .where(goods_nomenclature_sid: chapter.goods_nomenclature_sid)
               .eager(*Serialization::NsNondeclarableService::HEADING_EAGER_LOAD)
               .take
               .children
               .each do |heading|
                 next if heading.declarable?

                 yield heading
        end
      end
    end

    def heading_cache_key(heading)
      HeadingSerializationService.cache_key(heading, actual_date, false, {})
    end

    def write_heading(heading)
      data = HeadingService::Serialization::NsNondeclarableService
               .new(heading, eager_reload: false)
               .serializable_hash

      Rails.cache.write(heading_cache_key(heading), data, expires_in: CACHE_TTL)
    end

    def write_subheading(subheading)
      CachedSubheadingService.new(
        subheading,
        actual_date,
        eager_reload: false,
      ).call
    end
  end
end
