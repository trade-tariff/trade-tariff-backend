RSpec.describe TariffKnowledge::PublicAtarRulingImporter do
  around do |example|
    travel_to(Time.zone.parse('2026-06-26 12:00:00 UTC')) { example.run }
  end

  describe '#import_file' do
    it 'imports preload rulings with flattened date and keyword fields' do
      path = Rails.root.join('tmp/public_atar_rulings_preload_spec.json')
      File.write(path, JSON.pretty_generate([ruling_hash(ref: '600015804', keywords: ['CEILING LIGHTS', 'OF GLASS'])]))

      result = described_class.new.import_file(path:)

      ruling = TariffKnowledge::PublicAtarRuling.by_ref('600015804').first
      expect(result.created_count).to eq(1)
      expect(ruling.commodity_code).to eq('9705100074')
      expect(ruling.goods_nomenclature_item_id).to eq('9705100074')
      expect(ruling.keywords).to eq(['CEILING LIGHTS', 'OF GLASS'])
      expect(ruling.validity_start_date).to eq(Date.new(2026, 6, 26))
      expect(ruling.validity_end_date).to eq(Date.new(2029, 6, 25))
      expect(ruling.raw_fields.to_h).to include('Keywords' => ['CEILING LIGHTS', 'OF GLASS'])
    ensure
      FileUtils.rm_f(path)
    end

    it 'normalizes subheading-level ATAR commodity codes for goods nomenclature associations' do
      path = Rails.root.join('tmp/public_atar_rulings_preload_spec.json')
      File.write(path, JSON.pretty_generate([ruling_hash(ref: '600010924', commodity_code: '630210')]))

      described_class.new.import_file(path:)

      ruling = TariffKnowledge::PublicAtarRuling.by_ref('600010924').first
      expect(ruling.commodity_code).to eq('630210')
      expect(ruling.goods_nomenclature_item_id).to eq('6302100000')
    ensure
      FileUtils.rm_f(path)
    end

    it 'counts malformed preload rows and continues importing valid rows' do
      path = Rails.root.join('tmp/public_atar_rulings_preload_spec.json')
      malformed = ruling_hash(ref: '600015805')
      malformed.delete('description')
      File.write(path, JSON.pretty_generate([malformed, ruling_hash(ref: '600015804')]))
      allow(Rails.logger).to receive(:warn)

      result = described_class.new.import_file(path:)

      expect(result.seen_count).to eq(2)
      expect(result.created_count).to eq(1)
      expect(result.failed_count).to eq(1)
      expect(TariffKnowledge::PublicAtarRuling.by_ref('600015804').first).to be_present
      expect(Rails.logger).to have_received(:warn).with(/Failed to import public ATAR 600015805/)
    ensure
      FileUtils.rm_f(path)
    end
  end

  describe '#call' do
    it 'imports rulings discovered from public listing pages' do
      source = instance_double(TariffKnowledge::PublicAtarRulingSource)
      allow(source).to receive(:refs_for_page).with(1).and_return(%w[600015804])
      allow(source).to receive(:refs_for_page).with(2).and_return([])
      allow(source).to receive(:ruling_for_ref).with('600015804').and_return(ruling(ref: '600015804'))

      result = described_class.new(source:).call(max_pages: 2)

      expect(result.seen_count).to eq(1)
      expect(result.created_count).to eq(1)
      expect(TariffKnowledge::PublicAtarRuling.by_ref('600015804').first).to be_present
    end

    it 'honours the requested import limit across listing pages' do
      source = instance_double(TariffKnowledge::PublicAtarRulingSource)
      allow(source).to receive(:refs_for_page).with(1).and_return(%w[600015804 600015805])
      allow(source).to receive(:ruling_for_ref).with('600015804').and_return(ruling(ref: '600015804'))

      result = described_class.new(source:).call(limit: 1, max_pages: 2)

      expect(result.seen_count).to eq(1)
      expect(result.created_count).to eq(1)
      expect(result.failed_count).to eq(0)
      expect(source).not_to have_received(:refs_for_page).with(2)
      expect(source).not_to have_received(:ruling_for_ref).with('600015805')
    end

    it 'updates known rulings while preserving their first seen timestamp' do
      first_seen_at = Time.zone.parse('2026-06-01 09:00:00 UTC')
      create(
        :tariff_knowledge_public_atar_ruling,
        ref: '600015804',
        description: 'Old description',
        first_seen_at:,
        last_seen_at: first_seen_at,
        fetched_at: first_seen_at,
      )
      source = instance_double(TariffKnowledge::PublicAtarRulingSource)
      allow(source).to receive(:refs_for_page).with(1).and_return(%w[600015804 600015805])
      allow(source).to receive(:refs_for_page).with(2).and_return([])
      allow(source).to receive(:ruling_for_ref).with('600015804').and_return(ruling(ref: '600015804', description: 'Updated description'))
      allow(source).to receive(:ruling_for_ref).with('600015805').and_return(ruling(ref: '600015805', description: 'New description'))

      result = described_class.new(source:).call(max_pages: 2)

      updated = TariffKnowledge::PublicAtarRuling.by_ref('600015804').first
      expect(result.created_count).to eq(1)
      expect(result.updated_count).to eq(1)
      expect(updated.description).to eq('Updated description')
      expect(updated.first_seen_at).to eq(first_seen_at)
      expect(updated.last_seen_at).to eq(Time.zone.now)
      expect(updated.fetched_at).to eq(Time.zone.now)
    end

    it 'continues past already imported listing pages' do
      create(:tariff_knowledge_public_atar_ruling, ref: '600015804')
      source = instance_double(TariffKnowledge::PublicAtarRulingSource)
      allow(source).to receive(:refs_for_page).with(1).and_return(%w[600015804])
      allow(source).to receive(:refs_for_page).with(2).and_return(%w[600015805])
      allow(source).to receive(:refs_for_page).with(3).and_return([])
      allow(source).to receive(:ruling_for_ref).with('600015804').and_return(ruling(ref: '600015804', description: 'Updated description'))
      allow(source).to receive(:ruling_for_ref).with('600015805').and_return(ruling(ref: '600015805', description: 'New description'))

      result = described_class.new(source:).call(max_pages: 3)

      expect(result.seen_count).to eq(2)
      expect(result.created_count).to eq(1)
      expect(result.updated_count).to eq(1)
      expect(TariffKnowledge::PublicAtarRuling.by_ref('600015804').first.description).to eq('Updated description')
      expect(TariffKnowledge::PublicAtarRuling.by_ref('600015805').first.description).to eq('New description')
    end

    it 'counts failed rulings and continues importing other refs' do
      source = instance_double(TariffKnowledge::PublicAtarRulingSource)
      allow(source).to receive(:refs_for_page).with(1).and_return(%w[600015804 600015805])
      allow(source).to receive(:refs_for_page).with(2).and_return([])
      allow(source).to receive(:ruling_for_ref).with('600015804').and_raise(TariffKnowledge::PublicAtarRulingSource::ExtractionError, 'missing Commodity code for ATAR 600015804')
      allow(source).to receive(:ruling_for_ref).with('600015805').and_return(ruling(ref: '600015805', description: 'New description'))
      allow(Rails.logger).to receive(:warn)

      result = described_class.new(source:).call(max_pages: 2)

      expect(result.seen_count).to eq(2)
      expect(result.created_count).to eq(1)
      expect(result.failed_count).to eq(1)
      expect(TariffKnowledge::PublicAtarRuling.by_ref('600015805').first.description).to eq('New description')
      expect(Rails.logger).to have_received(:warn).with(/Failed to import public ATAR 600015804/)
    end
  end

  def ruling_hash(ref:, commodity_code: '9705100074', description: 'Venini, Cardin lights - Set of five.', keywords: ['CEILING LIGHTS'])
    {
      'ref' => ref,
      'commodity_code' => commodity_code,
      'goods_nomenclature_item_id' => commodity_code.ljust(10, '0'),
      'description' => description,
      'keywords' => keywords,
      'justification' => 'Classification has been determined in accordance with GIR 1.',
      'validity_start_date' => '2026-06-26',
      'validity_end_date' => '2029-06-25',
      'source_url' => "https://www.tax.service.gov.uk/search-for-advance-tariff-rulings/ruling/#{ref}",
      'raw_fields' => {
        'Start date' => '26 Jun 2026',
        'Expiry date' => '25 Jun 2029',
        'Commodity code' => commodity_code,
        'Description' => description,
        'Keywords' => keywords,
        'Justification' => 'Classification has been determined in accordance with GIR 1.',
      },
    }
  end

  def ruling(**attributes)
    TariffKnowledge::PublicAtarRulingSource::Ruling.new(**ruling_hash(**attributes).symbolize_keys)
  end
end
