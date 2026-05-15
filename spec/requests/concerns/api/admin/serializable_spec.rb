RSpec.describe Api::Admin::Serializable, :admin do
  # Use a real controller that includes the concern via AdminController.
  # We test through a concrete subclass to avoid stubbing the subject.
  subject(:controller_instance) do
    controller = Api::Admin::GreenLanes::ExemptionsController.new
    controller.instance_variable_set(:@_action_has_layout, false)
    controller
  end

  before do
    allow(TradeTariffBackend).to receive(:service).and_return('xi')
  end

  describe '#serialize' do
    it 'instantiates the serializer class with the given arguments and returns the hash' do
      exemption = build(:green_lanes_exemption)
      result = controller_instance.send(:serialize, exemption)
      expect(result).to include(:data)
    end
  end

  describe '#serialize_errors' do
    let(:record) { instance_double(GreenLanes::Exemption) }
    let(:error_service) { instance_double(Api::Admin::ErrorSerializationService, call: { errors: [] }) }

    before do
      allow(Api::Admin::ErrorSerializationService).to receive(:new).with(record).and_return(error_service)
    end

    it 'delegates to ErrorSerializationService' do
      result = controller_instance.send(:serialize_errors, record)
      expect(Api::Admin::ErrorSerializationService).to have_received(:new).with(record)
      expect(result).to eq({ errors: [] })
    end
  end
end
