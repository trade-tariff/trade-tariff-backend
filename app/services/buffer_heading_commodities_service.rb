# This service is responsible for reducing the number of heading.commodities_dataset queries that are run as part
# of prewarming heading and subheading caches and hugely improves performance of these processes.
class BufferHeadingCommoditiesService
  def call
    previous_heading_commodities = Thread.current[:heading_commodities]

    Thread.current[:heading_commodities] = heading_commodities

    yield if block_given?
  ensure
    Thread.current[:heading_commodities] = previous_heading_commodities
  end

  private

  def heading_commodities
    applicable_headings.each_with_object({}) do |heading, acc|
      acc[heading.short_code] = heading.commodities_dataset.eager(:goods_nomenclature_indents, :goods_nomenclature_descriptions).all
    end
  end

  def applicable_headings
    Heading.actual.reject(&:declarable)
  end
end
