module AncestorChainDescription
  extend ActiveSupport::Concern

  def ancestor_chain_description
    all_items = ancestors + [self]
    all_items.filter_map { |gn| gn.formatted_description.presence }.join(' > ')
  end
end
