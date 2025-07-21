require 'rails_helper'

RSpec.describe EnquiryForm::CsvUploaderService do
  let(:csv_data) { "CSV,Content,Here\nA,B,C" }

  let(:submission) do
    create(
      :enquiry_form_submission,
      reference_number: 'XYZ123',
      created_at: Time.zone.parse('2025-07-21 12:34:56'),
      csv_url: nil
    )
  end

  subject { described_class.new(submission, csv_data) }

  describe '#upload' do
    let(:expected_path) { "uk/enquiry_forms/2025/7/XYZ123.csv" }

    before do
      allow(TariffSynchronizer::FileService).to receive(:write_file)
    end

    it 'writes the CSV file with the correct path and data' do
      subject.upload

      expect(TariffSynchronizer::FileService).to have_received(:write_file)
        .with(expected_path, csv_data)
    end

    it 'updates the submission with the csv_url' do
      expect { subject.upload }.to change { submission.reload.csv_url }.to(expected_path)
    end

    it 'logs the upload' do
      expect(Rails.logger).to receive(:info)
        .with("Uploaded enquiry form CSV for XYZ123 to #{expected_path}")

      subject.upload
    end
  end

  describe '#filepath_for' do
    it 'generates the correct path based on submission date and reference' do
      expect(subject.filepath_for(submission)).to eq("uk/enquiry_forms/2025/7/XYZ123.csv")
    end
  end
end
