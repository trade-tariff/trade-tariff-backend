module AncestorChainDescription
  extend ActiveSupport::Concern

  def ancestor_chain_description
    all_items = ancestors + [self]
    all_items.filter_map { |gn| gn.description_html.presence }.join(' >> ')
  end
end
