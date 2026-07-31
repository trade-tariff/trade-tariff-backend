require 'open3'

RSpec.describe 'Notify configuration' do
  subject(:configuration_values) { notify_configuration_for(environment) }

  let(:environment) { 'development' }

  def notify_configuration_for(environment)
    initializer = Rails.root.join('config/initializers/notify.rb')
    script = <<~RUBY
      load #{initializer.to_s.inspect}
      puts [
        NOTIFY_CONFIGURATION.dig(:templates, :enquiry_form, :submission),
        NOTIFY_CONFIGURATION.dig(:templates, :myott, :tariff_change),
        NOTIFY_CONFIGURATION.dig(:reply_to, :tariff_management),
        NOTIFY_CONFIGURATION.dig(:templates, :notifications, :appendix5a),
        NOTIFY_CONFIGURATION.dig(:templates, :notifications, :customs_tariff_update),
      ]
    RUBY
    output, error, status = Open3.capture3({ 'ENVIRONMENT' => environment }, RbConfig.ruby, '-e', script)

    raise error unless status.success?

    output.lines(chomp: true)
  end

  context 'when running in production' do
    let(:environment) { 'production' }

    it 'uses the production templates and reply-to address' do
      expect(configuration_values).to eq(%w[
        104e74e3-8f43-4642-a594-4d4ef931b121
        5db33f13-7235-4ed8-b704-e3fddc01ee09
        61e19d5e-4fae-4b7e-aa2e-cd05a87f4cf8
        c35e387b-a2b8-4308-997c-06e1f3b36900
        02da9ea8-4919-45af-a9d4-68c908f49c9c
      ])
    end
  end

  context 'when running in staging' do
    let(:environment) { 'staging' }

    it 'uses the staging templates and reply-to address' do
      expect(configuration_values).to eq(%w[
        6033e45a-7029-4c5a-b4d3-e52ba111c9b4
        53c88c0c-69be-4375-829f-c6fbb1b9e2ef
        ed4f4168-e8c5-4b80-94b9-050c86a40f0f
        943fd08f-d9f0-47e0-b9dd-40284f308414
        eae01fd6-3e73-4a21-83ed-175eec3701c5
      ])
    end
  end

  context 'when running in development' do
    it 'uses the development templates and reply-to address' do
      expect(configuration_values).to eq(%w[
        180f1b06-3d77-4da5-9b19-2101a74fd1b8
        d25ab0ca-0114-47dc-954a-488516301580
        e780283a-471f-42ae-a573-4364ef604fea
        7b53d787-2659-4cd2-9e45-afe93ad61eec
        b99d0cef-0dce-414f-b3e2-28cf25075a43
      ])
    end
  end
end
