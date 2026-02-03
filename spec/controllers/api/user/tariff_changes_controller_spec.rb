RSpec.describe Api::User::TariffChangesController do
  include_context 'with user API authentication'

  let(:date) { Date.parse('2025-10-28') }
  let(:package) { instance_double(Axlsx::Package) }
  let(:stream) { StringIO.new('mock excel data') }

  describe '#download' do
    context 'when there are changes' do
      before do
        allow(TariffChangesService).to receive(:generate_report_for).with(date, user).and_return(package)
        allow(package).to receive(:to_stream).and_return(stream)
      end

      it 'calls TariffChangesService with the correct date and user' do
        get :download, params: { as_of: date.to_s }

        expect(TariffChangesService).to have_received(:generate_report_for).with(date, user)
      end

      it 'returns an Excel file with correct headers' do
        get :download, params: { as_of: date.to_s }

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to eq('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
        expect(response.headers['Content-Disposition']).to include('attachment')
        expect(response.headers['Content-Disposition']).to include('commodity_watch_list_changes_2025_10_28.xlsx')
      end

      it 'sends the file data' do
        get :download, params: { as_of: date.to_s }

        expect(response.body).to eq('mock excel data')
      end
    end

    context 'when there are no changes' do
      before do
        allow(TariffChangesService).to receive(:generate_report_for).with(date, user).and_return(nil)
      end

      it 'returns a not found error' do
        get :download, params: { as_of: date.to_s }

        expect(response).to have_http_status(:not_found)
        expect(JSON.parse(response.body)).to eq({ 'error' => 'No changes found' })
      end
    end

    context 'when as_of param is not provided' do
      before do
        allow(TariffChangesService).to receive(:generate_report_for).with(Time.zone.yesterday, user).and_return(package)
        allow(package).to receive(:to_stream).and_return(stream)
      end

      it 'defaults to yesterday' do
        freeze_time do
          get :download

          expect(TariffChangesService).to have_received(:generate_report_for).with(Time.zone.yesterday, user)
        end
      end
    end

    context 'when as_of param is provided' do
      let(:custom_date) { Date.parse('2024-12-15') }

      before do
        allow(TariffChangesService).to receive(:generate_report_for).with(custom_date, user).and_return(package)
        allow(package).to receive(:to_stream).and_return(stream)
      end

      it 'uses the provided date' do
        get :download, params: { as_of: custom_date.to_s }

        expect(TariffChangesService).to have_received(:generate_report_for).with(custom_date, user)
      end
    end

    context 'when user is not authenticated' do
      before do
        request.headers['Authorization'] = nil
      end

      it 'returns unauthorized' do
        get :download, params: { as_of: date.to_s }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
