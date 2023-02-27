Sequel.migration do
  # IMPORTANT! Data migrations up block should be idempotent (reruns of up should produce the same effect)
  # they may get re-run as part of data rollbacks but the rollback (down) function of the data migration will not get invoked
  up do
    if TradeTariffBackend.uk?
      GoodsNomenclatureDescription.where(
        goods_nomenclature_description_period_sid: 158_562,
        goods_nomenclature_sid: 104_214,
        filename: 'tariff_dailyExtract_v1_20230112T235959.gzip',
      ).first.tap do |gn|
        if gn.present?
          gn.description = <<~DESC
            Mixture of phytosterols containing by weight:
            - 35% or more but not more than 88% sitosterols,
            - 20% or more but not more than 63% campesterols,
            - 14% or more but not more than 38% stigmasterols,
            - not more than 13% brassicasterols,
            - not more than 10% other stanols, and
            - not more than 10% other sterols
          DESC

          gn.save
        end
      end

      GoodsNomenclatureDescription.where(
        goods_nomenclature_description_period_sid: 158_563,
        goods_nomenclature_sid: 103_636,
        filename: 'tariff_dailyExtract_v1_20230112T235959.gzip',
      ).first.tap do |gn|
        if gn.present?
          gn.description = <<~DESC
            Turbine housing of turbochargers, with a hole to insert a turbine wheel, whereby the hole has a diameter of 28mm or more, but not more than 181mm
          DESC

          gn.save
        end
      end

      GoodsNomenclatureDescription.where(
        goods_nomenclature_description_period_sid: 158_565,
        goods_nomenclature_sid: 104_474,
        filename: 'tariff_dailyExtract_v1_20230112T235959.gzip',
      ).first.tap do |gn|
        if gn.present?
          gn.description = <<~DESC
            Actuator for a single-stage turbocharger, with:
            - a pressure inlet pipe and a control rod with a working stroke of 15mm or more but not more than 40mm,
            - a maximum length of the actuator including control rod of not more than 400mm,
            - a maximum diameter of the can at the widest point of not more than 140mm, and
            - a maximum height of the can without control rod of not more than 140mm
          DESC

          gn.save
        end
      end

      GoodsNomenclatureDescription.where(
        goods_nomenclature_description_period_sid: 158_566,
        goods_nomenclature_sid: 98_652,
        filename: 'tariff_dailyExtract_v1_20230112T235959.gzip',
      ).first.tap do |gn|
        if gn.present?
          gn.description = <<~DESC
            Wire harness or cable for steering system:
            - for an operating voltage of 12V,
            - with connectors on both sides,
            - whether or not with anchor clamps of plastic for mounting on a motor vehicle steering box
          DESC

          gn.save
        end
      end

      GoodsNomenclatureDescription.where(
        goods_nomenclature_description_period_sid: 158_568,
        goods_nomenclature_sid: 106_160,
      ).first.tap { |gn|
        if gn.present?
          gn.description = <<~DESC
            Wires of an alloy of titanium:
            - with a niobium content by weight of 42% or more, but not more than 47%,
            - with a diameter of 2,36mm or more, but not more than 7,85mm,
            - in coils of 15kg or more, but not more than 45kg,
            - complying with standard AMS 4982
          DESC
        end
      }.save

      GoodsNomenclatureDescription.where(
        goods_nomenclature_description_period_sid: 158_570,
        goods_nomenclature_sid: 103_632,
      ).first.tap { |gn|
        if gn.present?
          gn.description = <<~DESC
            Exhaust manifold with turbine housing of turbochargers, with a hole to insert a turbine wheel, whereby the hole has a diameter of 28mm or more, but not more than 181mm
          DESC
        end
      }.save

      GoodsNomenclatureDescription.where(
        goods_nomenclature_description_period_sid: 158_571,
        goods_nomenclature_sid: 103_633,
      ).first.tap { |gn|
        if gn.present?
          gn.description = <<~DESC
            Exhaust manifold with turbine housing of turbochargers, with a hole to insert a turbine wheel, whereby the hole has a diameter of 28mm or more, but not more than 181mm
          DESC
        end
      }.save
    end
  end

  down do
    # We're not going to reverse on nans
  end
end
