RSpec.describe VatGuidance::SpikeTariffSnapshotRefresher do
  subject(:refreshed) do
    described_class.new(snapshot, retrieved_at: '2026-08-20T12:00:00Z', fetcher: fetcher).call
  end

  let(:snapshot) { JSON.parse(File.read(VAT_GUIDANCE_POC_ROOT.join('data/vat_guidance/spike_tariff_snapshot.json'))) }
  let(:fetcher) do
    lambda do |url|
      code = url[%r{/commodities/(\d{10})}, 1]
      unless code
        origin = snapshot.fetch('measures').find { |measure| measure.fetch('source_url') == url }
        next '{}' if url.include?('/v2/measures/')

        included = origin.fetch('declarable_commodity_codes').map do |commodity_code|
          {
            'type' => 'commodity',
            'attributes' => { 'declarable' => true, 'goods_nomenclature_item_id' => commodity_code },
          }
        end
        next JSON.generate('included' => included)
      end

      measures = snapshot.fetch('measures').select { |measure| measure.fetch('connection_commodity_codes').include?(code) }
      additional_codes = measures.map do |measure|
        {
          'id' => measure.fetch('additional_code_id'),
          'type' => 'additional_code',
          'attributes' => { 'code' => measure.fetch('additional_code') },
        }
      end
      vat_measures = measures.map do |measure|
        {
          'id' => measure.fetch('measure_id'),
          'type' => 'measure',
          'attributes' => { 'vat' => true, 'import' => true },
          'relationships' => {
            'measure_type' => { 'data' => { 'id' => '305' } },
            'additional_code' => { 'data' => { 'id' => measure.fetch('additional_code_id') } },
          },
        }
      end
      JSON.generate(
        'data' => { 'attributes' => { 'declarable' => true, 'goods_nomenclature_item_id' => code } },
        'included' => additional_codes + vat_measures,
      )
    end
  end

  it 'independently captures every scoped commodity and validates exact VAT measures' do
    expect(refreshed.fetch('schema_version')).to eq(2)
    expect(refreshed.fetch('commodity_measure_inventory').size).to eq(11)
    expect(refreshed.fetch('measures')).to all(include('source_response_sha256' => match(/\A[0-9a-f]{64}\z/)))
    expect { VatGuidance::TariffSnapshotContract.new(refreshed).validate! }.not_to raise_error
  end

  it 'fails when a commodity endpoint reports an unpinned non-standard VAT measure' do
    original_fetcher = fetcher
    bad_fetcher = lambda do |url|
      body = original_fetcher.call(url)
      next body unless url.end_with?('/commodities/6506101000')

      response = JSON.parse(body)
      response.fetch('included') << {
        'id' => '-999',
        'type' => 'measure',
        'attributes' => { 'vat' => true, 'import' => true },
        'relationships' => {
          'measure_type' => { 'data' => { 'id' => '305' } },
          'additional_code' => { 'data' => { 'id' => '-1009206007' } },
        },
      }
      JSON.generate(response)
    end

    expect {
      described_class.new(snapshot, retrieved_at: '2026-08-20T12:00:00Z', fetcher: bad_fetcher).call
    }.to raise_error(described_class::RefreshError, /inventory mismatch/)
  end
end
