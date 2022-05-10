RSpec.describe Api::Admin::CommoditiesController do
  describe 'GET #index' do
    subject(:do_request) do
      get api_commodities_path(format: :csv)
      response.body
    end

    before do
      allow(TimeMachine).to receive(:at).and_call_original
    end

    it 'contains the correct headers' do
      do_request

      expect(response.body).to include("SID,Commodity code,Product line suffix,Description,Start date,End date,Indentation,End line,ItemIDPlusPLS\n")
    end

    it 'calls the TimeMachine with the correct Date' do
      do_request

      expect(TimeMachine).to have_received(:at).with(Time.zone.today)
    end

    it_behaves_like 'a successful csv response' do
      let(:path) { '/admin/commodities' }
      let(:expected_filename) { "uk-commodities-#{Time.zone.today.iso8601}.csv" }

      before do
        create(:commodity)
      end
    end
  end
end
