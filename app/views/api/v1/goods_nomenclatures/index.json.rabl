collection @commodities
cache "goods-nomenclatures-#{@as_of.strftime('%Y%m%d')}.json" # , expires_at: actual_date.end_of_day

attribute :goods_nomenclature_sid => :sid
attribute :goods_nomenclature_item_id => :goods_nomenclature_item_id
attribute :description => :description
attribute :number_indents => :number_of_indents
attribute :producline_suffix => :product_line_suffix

node do |c|
  attribute :href => api_path_builder(c)
end
