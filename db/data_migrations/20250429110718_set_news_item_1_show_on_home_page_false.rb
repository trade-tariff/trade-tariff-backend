Sequel.migration do
  up do
    if TradeTariffBackend.uk?
      News::Item.where(title: 'Are you importing goods into Northern Ireland? ').update(show_on_home_page: false, end_date: Date.today)
    end
  end

  down do
    News::Item.where(title: 'Are you importing goods into Northern Ireland? ').update(show_on_home_page: true, end_date: nil)
  end
end