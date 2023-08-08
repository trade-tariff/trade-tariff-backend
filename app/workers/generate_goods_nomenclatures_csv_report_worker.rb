class GenerateGoodsNomenclaturesCsvReportWorker
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
    Chapter
      .non_hidden
      .eager(
        :goods_nomenclature_descriptions,
        ancestors: :goods_nomenclature_descriptions,
        descendants: :goods_nomenclature_descriptions,
      )
      .all
      .each_with_object([]) do |chapter, acc|
        acc << chapter
        acc.concat chapter.descendants
      end
  end
end
