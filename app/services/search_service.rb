# SearchService is responsible for issuing search queries
# it tries to do ExactSearch first in case search term consists
# of numerical values. We can guess if that was a Section, Chapter,
# Heading or Commodity code and redirect the user straight there.
#
# Otherwise it issues FuzzySearch that searches for results inside
# green pages (synonyms) index as well as the main goods nomenclature
# index and persents those results in single response. Fuzzy searching
# functionality is split into ReferenceMatch and GoodsNomenclatureMatch
# classes respectively.

class SearchService
  INDEX_SIZE_MAX = 10_000 # ElasticSearch does default pagination for 10 entries
  # per page. We do not do pagination when displaying
  # results so have a constant much bigger than possible
  # index size for size value.

  include ActiveModel::Validations
  include ActiveModel::Conversion
  include CustomRegex

  class EmptyQuery < StandardError
  end

  attr_reader :q, :result, :data_serializer
  attr_accessor :resource_id

  delegate :serializable_hash, to: :result

  def initialize(data_serializer, params = {})
    if params.present?
      params.each do |name, value|
        if respond_to?(:"#{name}=")
          send(:"#{name}=", value)
        end
      end
    end
    @data_serializer = data_serializer
  end

  def as_of
    @as_of || Time.zone.today
  end

  def as_of=(date)
    date ||= Time.zone.today.to_s
    @as_of = begin
      Date.parse(date)
    rescue StandardError
      Time.zone.today
    end
  end

  def q=(term)
    # use `cas_number_regex` to try to find a CAS number, then
    # if search term has no letters extract the digits
    # and perform search with just the digits (i.e., `no_alpha_regex`)
    # otherwise, ignore [ and ] characters to avoid range searches
    @q = if (m = cas_number_regex.match(term.to_s.first(100)))
           m[1]
         elsif cus_number_regex.match?(term) && digit_regex.match?(term)
           term
         elsif no_alpha_regex.match?(term) && digit_regex.match?(term)
           term.scan(/\d+/).join
         elsif no_alpha_regex.match(term) && !digit_regex.match?(term)
           ''
         else
           term.to_s.gsub(ignore_brackets_regex, '')
         end
  end

  def exact_match?
    result.is_a?(ExactSearch)
  end

  def to_json(_config = {})
    perform

    data_serializer.perform(result)
  end

  def persisted?
    false
  end

  private

  def perform
    @result = if SearchService::RogueSearchService.call(q)
                NullSearch.new(q, as_of)
              else
                if q.present?
                  exact_search.presence || fuzzy_search.presence
                end || NullSearch.new(q, as_of)
              end

    @result
  end

  def exact_search
    ExactSearch.new(q, as_of, resource_id).search!
  end

  def fuzzy_search
    FuzzySearch.new(q, as_of).search!
  end
end
