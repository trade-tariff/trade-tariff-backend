RSpec.describe TariffKnowledge::SyntheticAtarImporter do
  # The header row copies the analysts' sheet: long headers with hints, and extra
  # columns (Row, Chapter title, Heading description) that the importer ignores.
  # All the data below is invented. Never put real analyst data in a fixture.
  let(:headers) do
    [
      'Row',
      'Chapter',
      'Chapter title',
      'Real user search (do not change)',
      'Times searched (May-Aug 2026)',
      'Likely heading (best guess - context only)',
      'Heading description',
      'Full product description - all classifying facts (material, use, state)',
      'Commodity code (10 digits)',
      'Status',
      'Completed by',
      'Notes',
    ]
  end

  def sheet_row(search:, chapter: '39', times: '25', heading: '3924', description: 'Plastic lunch box with a lid, for carrying food.', code: '3924100000', status: 'Done', completed_by: 'AB', notes: 'Tableware of plastics.')
    [1, chapter, 'Plastics', search, times, heading, 'Tableware', description, code, status, completed_by, notes]
  end

  def csv_for(*rows, headers: self.headers)
    CSV.generate do |csv|
      csv << headers
      rows.each { |row| csv << row }
    end
  end

  # Only the five required columns, in the plainest header spelling.
  def minimal_csv(*rows)
    CSV.generate do |csv|
      csv << ['Chapter', 'Real user search', 'Full product description', 'Commodity code', 'Status']
      rows.each { |row| csv << row }
    end
  end

  def import(*rows, **options)
    described_class.new(csv_content: csv_for(*rows, **options)).call
  end

  describe '#call' do
    it 'creates a record for each finished row, matching columns by their start' do
      result = import(sheet_row(search: 'lunch box'), sheet_row(search: 'bucket', chapter: '39', code: '3923100000', notes: nil))

      expect(result).to be_success
      expect(result).to have_attributes(created_count: 2, updated_count: 0, unchanged_count: 0, skipped_count: 0, total_count: 2)
      expect(TariffKnowledge::SyntheticAtar.by_real_user_search('lunch box').first).to have_attributes(
        chapter: '39',
        real_user_search: 'lunch box',
        times_searched: 25,
        likely_heading: '3924',
        description: 'Plastic lunch box with a lid, for carrying food.',
        goods_nomenclature_item_id: '3924100000',
        completed_by: 'AB',
        notes: 'Tableware of plastics.',
      )
      expect(TariffKnowledge::SyntheticAtar.by_real_user_search('bucket').first.notes).to be_nil
    end

    it 'skips rows that are not finished and counts them' do
      result = import(
        sheet_row(search: 'lunch box'),
        sheet_row(search: 'not started', status: 'Not started', description: '', code: ''),
        sheet_row(search: 'in progress', status: 'In progress'),
        sheet_row(search: 'skipped', status: 'Skipped'),
        sheet_row(search: 'no description', description: ''),
        sheet_row(search: 'no code', code: ''),
      )

      expect(result).to be_success
      expect(result).to have_attributes(created_count: 1, skipped_count: 5)
      expect(TariffKnowledge::SyntheticAtar.count).to eq(1)
    end

    it 'succeeds with nothing created when no row is finished' do
      result = import(sheet_row(search: 'a', status: 'Not started'), sheet_row(search: 'b', status: 'Not started'))

      expect(result).to be_success
      expect(result).to have_attributes(created_count: 0, total_count: 0, skipped_count: 2)
    end

    it 'treats the status as case-insensitive' do
      expect(import(sheet_row(search: 'lunch box', status: ' DONE '))).to have_attributes(created_count: 1)
    end

    it 'pads a chapter that lost its leading zero' do
      result = import(sheet_row(search: 'live pony', chapter: '1', code: '0101210000'))

      expect(result).to be_success
      expect(TariffKnowledge::SyntheticAtar.first.chapter).to eq('01')
    end

    context 'when a record with the same search already exists' do
      let!(:existing) { create(:tariff_knowledge_synthetic_atar, real_user_search: 'Lunch Box', goods_nomenclature_item_id: '3923100000') }

      it 'updates it, ignoring case and spacing, instead of creating a second one' do
        result = import(sheet_row(search: ' lunch   box ', code: '3924100000'))

        expect(result).to have_attributes(created_count: 0, updated_count: 1, unchanged_count: 0)
        expect(TariffKnowledge::SyntheticAtar.count).to eq(1)
        expect(existing.reload.goods_nomenclature_item_id).to eq('3924100000')
      end

      it 'records an update version' do
        import(sheet_row(search: 'lunch box', code: '3924100000'))

        expect(existing.versions.map(&:event)).to eq(%w[create update])
      end
    end

    it 'reports rows as unchanged and adds no versions when the same file is imported again' do
      file = csv_for(sheet_row(search: 'lunch box'), sheet_row(search: 'bucket', code: '3923100000'))
      described_class.new(csv_content: file).call
      versions_before = Version.where(item_type: 'TariffKnowledge::SyntheticAtar').count

      result = described_class.new(csv_content: file).call

      expect(result).to have_attributes(created_count: 0, updated_count: 0, unchanged_count: 2)
      expect(Version.where(item_type: 'TariffKnowledge::SyntheticAtar').count).to eq(versions_before)
    end

    it 'reports rows as unchanged when the optional cells are blank, as they are in the real sheet' do
      file = csv_for(sheet_row(search: 'lunch box', times: '', heading: '', completed_by: '', notes: ''))
      described_class.new(csv_content: file).call
      versions_before = Version.where(item_type: 'TariffKnowledge::SyntheticAtar').count

      result = described_class.new(csv_content: file).call

      expect(result).to have_attributes(created_count: 0, updated_count: 0, unchanged_count: 1)
      expect(Version.where(item_type: 'TariffKnowledge::SyntheticAtar').count).to eq(versions_before)
    end

    it 'leaves stored values alone for columns that are not in the file' do
      existing = create(:tariff_knowledge_synthetic_atar, real_user_search: 'lunch box', completed_by: 'ZZ', notes: 'Keep me')
      file = minimal_csv(['39', 'lunch box', 'A new description of the lunch box.', '3924100000', 'Done'])

      result = described_class.new(csv_content: file).call

      expect(result).to have_attributes(updated_count: 1)
      expect(existing.reload).to have_attributes(description: 'A new description of the lunch box.', completed_by: 'ZZ', notes: 'Keep me')
    end

    it 'accepts a file that starts with a byte order mark' do
      file = "﻿#{minimal_csv(['39', 'lunch box', 'A lunch box.', '3924100000', 'Done'])}"

      expect(described_class.new(csv_content: file).call).to have_attributes(created_count: 1)
    end

    it 'records who imported the rows' do
      TradeTariffRequest.whodunnit = 'user-123'

      import(sheet_row(search: 'lunch box'))

      expect(TariffKnowledge::SyntheticAtar.first.versions.map(&:whodunnit)).to eq(%w[user-123])
    ensure
      TradeTariffRequest.whodunnit = nil
    end

    context 'when a finished row has an error' do
      it 'saves nothing and reports the line number when the code has a dropped leading zero' do
        result = import(sheet_row(search: 'lunch box'), sheet_row(search: 'live pony', chapter: '01', code: '101210000'))

        expect(result).not_to be_success
        expect(result.row_errors.map { |error| error[:detail] }).to eq(
          ['Line 3: Commodity code must be exactly 10 digits (check that a leading zero has not been dropped)'],
        )
        expect(result.row_errors.first.dig(:source, :pointer)).to eq('/data/attributes/csv/3/goods_nomenclature_item_id')
        expect(TariffKnowledge::SyntheticAtar.count).to eq(0)
      end

      it 'reports a search that still shows the placeholder' do
        result = import(sheet_row(search: '(no real search available - please invent one)'))

        expect(result).not_to be_success
        expect(result.row_errors.first[:detail]).to include('Line 2: Real user search still shows the')
        expect(TariffKnowledge::SyntheticAtar.count).to eq(0)
      end

      it 'reports a missing search term' do
        result = import(sheet_row(search: ''))

        expect(result).not_to be_success
        expect(result.row_errors.first[:detail]).to start_with('Line 2: Real user search')
      end

      it 'reports a search repeated in the file, ignoring case, on the later line only' do
        result = import(sheet_row(search: 'Lunch Box'), sheet_row(search: 'bucket', code: '3923100000'), sheet_row(search: 'lunch box'))

        expect(result).not_to be_success
        expect(result.row_errors.map { |error| error[:detail] }).to eq(
          ['Line 4: Real user search appears more than once in the file (first on line 2)'],
        )
        expect(TariffKnowledge::SyntheticAtar.count).to eq(0)
      end

      it 'reports every error, not just the first' do
        result = import(sheet_row(search: 'one', code: '1'), sheet_row(search: 'two', chapter: '123'))

        expect(result.row_errors.map { |error| error[:detail][/\ALine \d+/] }).to eq(['Line 2', 'Line 3'])
      end

      it 'does not report errors for rows that are skipped as unfinished' do
        result = import(sheet_row(search: 'lunch box'), sheet_row(search: '(no real search available)', status: 'Not started', code: '12'))

        expect(result).to be_success
        expect(result).to have_attributes(created_count: 1, skipped_count: 1)
      end

      it 'reports a times searched value that is not a number' do
        result = import(sheet_row(search: 'lunch box', times: 'lots'))

        expect(result).not_to be_success
        expect(result.row_errors.first[:detail]).to start_with('Line 2: Times searched')
      end
    end

    context 'when the file is not usable' do
      it 'reports the missing required columns and saves nothing' do
        content = CSV.generate do |csv|
          csv << ['Chapter', 'Real user search', 'Status']
          csv << ['39', 'lunch box', 'Done']
        end

        result = described_class.new(csv_content: content).call

        expect(result).not_to be_success
        expect(result.summary_errors.map { |error| error[:detail] }).to eq(
          ['The file is missing these columns: Full product description and Commodity code'],
        )
      end

      it 'reports an empty file' do
        result = described_class.new(csv_content: '').call

        expect(result).not_to be_success
        expect(result.summary_errors.first[:detail]).to start_with('The file is missing these columns')
      end

      it 'reports a file that cannot be parsed' do
        result = described_class.new(csv_content: "Chapter,Status\n\"unclosed,Done").call

        expect(result).not_to be_success
        expect(result.summary_errors.first[:detail]).to start_with('CSV could not be parsed')
      end
    end
  end
end
