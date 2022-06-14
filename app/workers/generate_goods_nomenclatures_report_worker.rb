class GenerateGoodsNomenclaturesReportWorker
  include Sidekiq::Worker

  sidekiq_options retry: false

  def perform
    TimeMachine.now { TariffSynchronizer::FileService.write_file(filename, serialized) }
  end

  private

  def filename
    "#{TradeTariffBackend.service}/goods_nomenclatures/#{Time.zone.today.iso8601}.csv"
  end

  def serialized
    Api::Admin::Csv::GoodsNomenclatureSerializer
      .new(goods_nomenclatures)
      .serialized_csv
  end

  def goods_nomenclatures
    GoodsNomenclature
      .dataset
      .eager(:goods_nomenclature_indents)
      .exclude(goods_nomenclature_item_id: HiddenGoodsNomenclature.codes)
      .all
  end
end
