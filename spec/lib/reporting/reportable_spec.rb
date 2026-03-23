RSpec.describe Reporting::Reportable do
  describe 'including the concern' do
    subject(:report_class) do
      reportable = described_class

      Class.new do
        include reportable

        def self.name
          'Reporting::Dummy'
        end

        class << self
          private

          def object_key
            'uk/reporting/2026/03/23/dummy.csv'
          end
        end
      end
    end

    it 'exposes report helpers as class methods' do
      expect(report_class).to respond_to(
        :with_report_logging,
        :instrument_report_step,
        :log_report_metric,
        :available_today?,
        :download_link_today,
      )
    end
  end
end
