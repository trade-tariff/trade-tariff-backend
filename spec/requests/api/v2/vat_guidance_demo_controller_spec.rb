RSpec.describe Api::V2::VatGuidanceDemoController, :v2 do
  describe 'GET #show' do
    subject(:payload) do
      api_get api_vat_guidance_demo_path
      JSON.parse(response.body)
    end

    it 'serves the validated, explicitly unapproved AI-1146 demo projection', :aggregate_failures do
      attributes = payload.dig('data', 'attributes')

      expect(response).to have_http_status(:ok)
      expect(payload.dig('data', 'type')).to eq('vat_guidance_demo')
      expect(attributes).to include('ticket' => 'AI-1146')
      expect(attributes.dig('spike_status', 'end_to_end_simulation_ready')).to be(true)
      expect(attributes.dig('spike_status', 'runtime_approved')).to be(false)
      expect(attributes.dig('spike_status', 'production_ready')).to be(false)
      expect(attributes.fetch('composed_commodity_journeys').size).to eq(11)
      expect(attributes.fetch('notice_journeys')).to contain_exactly(
        include(
          'id' => 'notice-701-14-food-exceptions',
          'title' => 'VAT Notice 701/14 — food exceptions',
          'applicable_commodity_codes' => %w[2005202000 2008939120 2008979890],
          'evidence_only' => true,
          'production_eligible' => false,
          'resolved_answer_paths' => contain_exactly(
            include('treatment' => 'standard'),
            include('treatment' => 'zero'),
          ),
        ),
        include(
          'id' => 'notice-709-1-catering-reference-expanded',
          'title' => 'VAT Notice 709/1 — catering and food exceptions',
          'applicable_commodity_codes' => %w[2005202000 2008939120 2008979890],
          'evidence_only' => true,
          'production_eligible' => false,
          'resolved_answer_paths' => contain_exactly(
            include('treatment' => 'standard'),
            include('treatment' => 'standard'),
            include('treatment' => 'zero'),
          ),
        ),
      )
    end
  end
end
