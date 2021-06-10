namespace :tariff do
  desc 'Installs Trade Tariff, creates relevant records, imports national data'
  task install: %w[environment
                   install:taric:sections
                   install:taric:section_notes
                   install:taric:chapter_notes]

  desc 'Reindex relevant entities on ElasticSearch'
  task reindex: %w[environment] do
    TradeTariffBackend.reindex
  end

  desc 'Pre-warm heavy headings cache'
  task pre_warm_cache: %w[environment] do
    TradeTariffBackend.pre_warm_headings_cache
  end

  desc 'Recache relevant entities on ElasticSearch'
  task recache: %w[environment] do
    TradeTariffBackend.recache
  end

  desc 'Add commodity footnotes for ECO licences where these is an export restriction'
  task add_missing_commodity_footnote: :environment do
    measure_type_id = MeasureType.all.detect { |mt| mt.description == 'Export authorization (Dual use)' }.values[:measure_type_id]
    footnote = Footnote.filter(footnote_id: '002', footnote_type_id: '05').first
    sql = %{
      SELECT DISTINCT goods_nomenclatures.goods_nomenclature_sid, goods_nomenclatures.goods_nomenclature_item_id,
      goods_nomenclatures.validity_start_date, producline_suffix,
      goods_nomenclatures.validity_end_date, goods_nomenclatures.operation
      FROM goods_nomenclatures
      LEFT JOIN measures ON (measures.goods_nomenclature_item_id = goods_nomenclatures.goods_nomenclature_item_id)
         WHERE ((measures.measure_type_id = '#{measure_type_id}')
        )
      AND NOT EXISTS (
      select 1 from footnote_association_goods_nomenclatures
      where footnote_association_goods_nomenclatures.footnote_type = '05'
      and footnote_association_goods_nomenclatures.footnote_id = '002'
      and goods_nomenclature_item_id = goods_nomenclatures.goods_nomenclature_item_id
      )
    }
    GoodsNomenclature.fetch(sql).all.each do |c|
      if c.footnote != footnote
        FootnoteAssociationGoodsNomenclature.associate_footnote_with_goods_nomenclature(c, footnote)
      end
    end
  end

  desc 'Download and apply Taric and CHIEF data'
  task sync: %w[environment sync:apply]

  namespace :sync do
    desc 'Update database by downloading and then applying CHIEF and TARIC updates via worker'
    task update: %i[environment class_eager_load] do
      UpdatesSynchronizerWorker.perform_async
    end

    desc 'Download pending Taric and CHIEF update files, Update tariff_updates table'
    task download: %i[environment class_eager_load] do
      TariffSynchronizer.download
    end

    desc 'Apply pending updates Taric and CHIEF'
    task apply: %i[environment class_eager_load] do
      TariffSynchronizer.apply
    end

    desc 'Rollback to specific date in the past'
    task rollback: %w[environment class_eager_load] do
      if ENV['DATE']
        if TradeTariffBackend.use_cds?
          TariffSynchronizer.rollback_cds(ENV['DATE'], ENV['KEEP'])
        else
          TariffSynchronizer.rollback(ENV['DATE'], ENV['KEEP'])
        end
      else
        raise ArgumentError, "Please set the date using environment variable 'DATE'"
      end
    end
  end

  namespace :install do
    desc 'Load Green Page (SearchReference) entities from reference file'
    task green_pages: :environment do
      ImportSearchReferences.reload
    end

    namespace :taric do
      desc 'Add Sections and associate to Chapters'
      task sections: :environment do
        ENV['RUNNING_TASK'] = 'enabled'
        load(File.join(Rails.root, 'db', 'import_sections.rb'))
        ENV.delete('RUNNING_TASK')
      end

      desc 'Dump Section notes'
      task dump_section_notes: :environment do
        SectionNote.all.each do |section_note|
          section_file = "db/notes/sections/#{section_note.section_id}.yaml"
          File.open(section_file, 'w') do |out|
            section_doc = {
              section: section_note.section_id,
              content: section_note.content,
            }
            YAML.dump(section_doc, out)
          end
        end
      end

      desc 'Load Section notes into database'
      task section_notes: :environment do
        Dir[Rails.root.join('db', 'notes', 'sections', '*')].each do |file|
          note = YAML.safe_load(File.read(file), [Symbol])
          section_note = SectionNote.find(section_id: note[:section]) || SectionNote.new(section_id: note[:section])
          section_note.content = note[:content]
          section_note.save
        rescue StandardError => e
          puts "Error loading: #{file}, #{e}"
        end
      end

      desc 'Dump Chapter notes'
      task dump_chapter_notes: :environment do
        ChapterNote.all.each do |chatper_note|
          chapter_file = "db/notes/chapters/#{chatper_note.section_id}_#{chatper_note.chapter_id.to_i}.yaml"
          File.open(chapter_file, 'w') do |out|
            chapter_doc = {
              section: chatper_note.section_id,
              chapter: chatper_note.chapter_id.to_i,
              content: chatper_note.content.force_encoding('ASCII-8BIT').encode('UTF-8', undef: :replace, replace: ''),
            }
            YAML.dump(chapter_doc, out)
          end
        end
      end

      desc 'Load Chapter notes into database'
      task chapter_notes: :environment do
        Dir[Rails.root.join('db', 'notes', 'chapters', '*')].each do |file|
          note = YAML.safe_load(File.read(file), [Symbol])
          chapter_note = ChapterNote.find(section_id: note[:section],
                                          chapter_id: note[:chapter].to_s) || ChapterNote.new(section_id: note[:section], chapter_id: note[:chapter].to_s)
          chapter_note.content = note[:content]
          chapter_note.save
        end
      end

      desc 'Load measurment unit abbriviations'
      task measurment_unit_abbr: :environment do
        [{ abbr: '% vol', code: 'ASV' },
         { abbr: '% vol/hl',             code: 'ASV', qualifier: 'X' },
         { abbr: 'ct/l',                 code: 'CCT' },
         { abbr: '100 p/st',             code: 'CEN' },
         { abbr: 'c/k',                  code: 'CTM' },
         { abbr: '10 000 kg/polar',      code: 'DAP' },
         { abbr: 'kg DHS',               code: 'DHS' },
         { abbr: '100 kg',               code: 'DTN' },
         { abbr: '100 kg/net eda',       code: 'DTN', qualifier: 'E' },
         { abbr: '100 kg common wheat',  code: 'DTN', qualifier: 'F' },
         { abbr: '100 kg/br',            code: 'DTN', qualifier: 'G' },
         { abbr: '100 kg live weight',   code: 'DTN', qualifier: 'L' },
         { abbr: '100 kg/net mas',       code: 'DTN', qualifier: 'M' },
         { abbr: '100 kg std qual',      code: 'DTN', qualifier: 'R' },
         { abbr: '100 kg raw sugar',     code: 'DTN', qualifier: 'S' },
         { abbr: '100 kg/net/%sacchar.', code: 'DTN', qualifier: 'Z' },
         { abbr: 'EUR',                  code: 'EUR' },
         { abbr: 'gi F/S',               code: 'GFI' },
         { abbr: 'g',                    code: 'GRM' },
         { abbr: 'GT',                   code: 'GRT' },
         { abbr: 'hl',                   code: 'HLT' },
         { abbr: '100 m',                code: 'HMT' },
         { abbr: 'kg C₅H₁₄ClNO',         code: 'KCC' },
         { abbr: 'tonne KCl',            code: 'KCL' },
         { abbr: 'kg',                   code: 'KGM' },
         { abbr: 'kg/tot/alc',           code: 'KGM', qualifier: 'A' },
         { abbr: 'kg/net eda',           code: 'KGM', qualifier: 'E' },
         { abbr: 'GKG',                  code: 'KGM', qualifier: 'G' },
         { abbr: 'kg/lactic matter',     code: 'KGM', qualifier: 'P' },
         { abbr: 'kg/raw sugar',         code: 'KGM', qualifier: 'S' },
         { abbr: 'kg/dry lactic matter', code: 'KGM', qualifier: 'T' },
         { abbr: '1000 l',               code: 'KLT' },
         { abbr: 'kg methylamines',      code: 'KMA' },
         { abbr: 'KM',                   code: 'KMT' },
         { abbr: 'kg N',                 code: 'KNI' },
         { abbr: 'kg H₂O₂',              code: 'KNS' },
         { abbr: 'kg KOH',               code: 'KPH' },
         { abbr: 'kg K₂O',               code: 'KPO' },
         { abbr: 'kg P₂O₅',              code: 'KPP' },
         { abbr: 'kg 90% sdt',           code: 'KSD' },
         { abbr: 'kg NaOH',              code: 'KSH' },
         { abbr: 'kg U',                 code: 'KUR' },
         { abbr: 'l alc. 100%',          code: 'LPA' },
         { abbr: 'l',                    code: 'LTR' },
         { abbr: 'L total alc.',         code: 'LTR', qualifier: 'A' },
         { abbr: '1000 p/st',            code: 'MIL' },
         { abbr: '1000 pa',              code: 'MPR' },
         { abbr: 'm²',                   code: 'MTK' },
         { abbr: 'm³',                   code: 'MTQ' },
         { abbr: '1000 m³',              code: 'MTQ', qualifier: 'C' },
         { abbr: 'm',                    code: 'MTR' },
         { abbr: '1000 kWh',             code: 'MWH' },
         { abbr: 'p/st',                 code: 'NAR' },
         { abbr: 'b/f',                  code: 'NAR', qualifier: 'B' },
         { abbr: 'ce/el',                code: 'NCL' },
         { abbr: 'pa',                   code: 'NPR' },
         { abbr: 'TJ',                   code: 'TJO' },
         { abbr: '1000 kg',              code: 'TNE' },
         { abbr: '1000 kg/net eda',      code: 'TNE', qualifier: 'E' },
         { abbr: '1000 kg/biodiesel',    code: 'TNE', qualifier: 'I' },
         { abbr: '1000 kg/fuel content', code: 'TNE', qualifier: 'J' },
         { abbr: '1000 kg/bioethanol',   code: 'TNE', qualifier: 'K' },
         { abbr: '1000 kg/net mas',      code: 'TNE', qualifier: 'M' },
         { abbr: '1000 kg std qual',     code: 'TNE', qualifier: 'R' },
         { abbr: '1000 kg/net/%saccha.', code: 'TNE', qualifier: 'Z' },
         { abbr: 'Watt',                 code: 'WAT' }].each do |m|
          MeasurementUnitAbbreviation.create(abbreviation: m[:abbr],
                                             measurement_unit_code: m[:code],
                                             measurement_unit_qualifier: m[:qualifier])
        end
      end
    end
  end

  desc 'Removes additional Trade Tariff entries'
  task remove: %w[environment remove:taric:sections]

  namespace :remove do
    namespace :updates do
      desc 'Remove pending tariff_update entries'
      task pending: :environment do
        Sequel::Model.db.run("DELETE FROM tariff_updates WHERE state = 'P'")
      end
    end

    namespace :taric do
      desc 'Remove Sections and Chapter<->Section association records'
      task sections: :environment do
        Section.dataset.delete
        Sequel::Model.db.run('DELETE FROM chapters_sections')
      end
    end
  end

  namespace :support do
    desc 'Create failed measures report'
    task failed_measures_report: %w[environment] do
      require 'csv'
      items = []
      CSV.open('data/failed-measures-report.csv', 'wb', col_sep: ';') do |csv|
        csv << ['Goods Nomenclature', 'Measure Type', 'Update File', 'Errors', 'Candidate Measure', 'Notes']
        Dir['data/measures/*'].select { |f| f.include?('failed') }.sort.each do |path|
          puts "Processing #{path}"
          file = File.open(path, 'r')
          origin = path.sub('-failed.json.txt', '.txt').split('/').last
          file.each_line do |line|
            line = JSON.parse(line)
            items << [
              line['goods_nomenclature_item_id'],
              line['measure_type_id'],
              origin,
              line['errors'],
              line,
            ]
          end
        end
        items.uniq { |i| [i[0], i[1], i[3]] }.each { |item| csv << item }
      end

      extra_namespaces = {
        'xmlns:oub' => 'urn:publicid:-:DGTAXUD:TARIC:MESSAGE:1.0',
        'xmlns:env' => 'urn:publicid:-:DGTAXUD:GENERAL:ENVELOPE:1.0',
      }

      items = items.map { |i| i[0] }.uniq.sort

      CSV.open('data/failed-measures-report-taric.csv', 'wb', col_sep: ';') do |csv|
        Dir['data/taric/*'].select { |path| path > 'data/taric/2017-05-31_TGB17101.xml' }.sort.each do |path|
          items.each do |item|
            puts "Processing #{item} #{path}"
            origin = path.split('/').last
            doc = Nokogiri::XML(File.open(path))
            matches = doc.xpath(
              "//oub:goods.nomenclature/oub:goods.nomenclature.item.id[contains(text(), '#{item}')]",
              extra_namespaces,
            )

            matches.each do |m|
              start_date = m.parent.children.select { |c| c.name == 'validity.start.date' }.first.try(:text)
              end_date = m.parent.children.select { |c| c.name == 'validity.end.date' }.first.try(:text)
              csv << [item, origin, start_date, end_date]
            end
          end
        end
      end
    end

    desc 'Check codes on EU website, put your codes in `codes` array'
    task check_codes_on_eu: %w[environment] do
      require 'net/http'
      codes = []
      not_on_eu = []
      codes.each do |code|
        puts "checking #{code}"
        url = "http://ec.europa.eu/taxation_customs/dds2/taric/measures.jsp?Lang=en&SimDate=20180105&Area=&MeasType=&StartPub=&EndPub=&MeasText=&GoodsText=&Taric=#{code}&search_text=goods&textSearch=&LangDescr=en&OrderNum=&Regulation=&measStartDat=&measEndDat="
        uri = URI(url)
        s = Net::HTTP.get(uri)
        not_on_eu << code unless s.include? 'TARIC measure information'
      end
      puts 'compeled'
      puts not_on_eu
    end
  end
end
