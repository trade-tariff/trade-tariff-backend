RSpec.describe Api::V2::ChemicalSubstancesController, type: :request do
  describe 'GET #index' do
    subject(:rendered) { make_request && response }

    let(:make_request) do
      create(:full_chemical, cus: '1234567890')

      get api_chemical_substances_path(params:, format: :json)
    end

    context 'when no filter is provided' do
      let(:params) { {} }

      it_behaves_like 'a successful jsonapi response'

      it { expect(rendered.body).to eq({ data: [] }.to_json) }
    end

    context 'when a filter is provided' do
      let(:params) { { filter: { cus: '1234567890' } } }

      it_behaves_like 'a successful jsonapi response'

      it 'calls the FullChemical.with_filter method' do
        allow(FullChemical).to receive(:with_filter).and_call_original
        rendered
        expect(FullChemical).to have_received(:with_filter).with(strong_params('cus' => '1234567890'))
      end

      it { expect(rendered.body).to match(/1234567890/) }
    end
  end
end
