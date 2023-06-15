require 'rails_helper'

RSpec.describe BulkSearch::ResultCollection do
  subject(:result_collection) { described_class.new(id:, status:, searches:) }

  let(:searches) do
    [
      { input_description: 'red herring' },
      { input_description: 'white bait' },
    ]
  end
  let(:id) { SecureRandom.uuid }
  let(:status) { BulkSearch::COMPLETE_STATE }

  describe '.build' do
    subject(:result_collection) { described_class.build(searches) }

    let(:searches) do
      [
        { attributes: { input_description: 'red herring' } },
        { attributes: { input_description: 'white bait' } },
      ]
    end

    it { expect(result_collection).to be_a(described_class) }
    it { expect(result_collection.id).to match(/^[a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12}$/) }
    it { expect(result_collection.status).to eq(BulkSearch::INITIAL_STATE.to_s) }
  end

  describe '#as_json' do
    subject(:result_collection) { described_class.new(id:, status:, searches:) }

    let(:searches) do
      [
        {
          ancestor_digits: 8,
          input_description: 'red herring',
          search_result_ancestors: [
            {
              short_code: '950720',
              goods_nomenclature_item_id: '9507200000',
              description: 'Fish-hooks, whether or not snelled',
              producline_suffix: '80',
              goods_nomenclature_class: 'Subheading',
              declarable: false,
              reason: 'matching_digit_ancestor',
              score: 32.99,
            },
          ],
        },
        {
          ancestor_digits: 8,
          input_description: 'white bait',
          search_result_ancestors: [
            {
              short_code: '160420',
              goods_nomenclature_item_id: '1604200000',
              description: 'Other prepared or preserved fish',
              producline_suffix: '80',
              goods_nomenclature_class: 'Subheading',
              declarable: false,
              reason: 'matching_digit_ancestor',
              score: 25.97,
            },
          ],
        },
      ]
    end

    it 'returns a hash representation of the result collection' do
      expected_result = {
        id:,
        status: 'completed',
        searches: [
          {
            input_description: 'red herring',
            search_result_ancestors: [
              { short_code: '950720',
                goods_nomenclature_item_id: '9507200000',
                description: 'Fish-hooks, whether or not snelled',
                producline_suffix: '80',
                goods_nomenclature_class: 'Subheading',
                declarable: false,
                score: 32.99,
                reason: 'matching_digit_ancestor' },
            ],
          },
          {
            input_description: 'white bait',
            search_result_ancestors: [
              {
                short_code: '160420',
                goods_nomenclature_item_id: '1604200000',
                description: 'Other prepared or preserved fish',
                producline_suffix: '80',
                goods_nomenclature_class: 'Subheading',
                declarable: false,
                score: 25.97,
                reason: 'matching_digit_ancestor',
              },
            ],
          },
        ],
      }

      expect(result_collection.as_json).to eq(expected_result)
    end
  end

  describe '#search_ids' do
    it { expect(result_collection.search_ids).to be_present }
  end

  describe '#message' do
    shared_examples_for 'a bulk search result collection message' do |status, message|
      let(:status) { status }

      it { expect(result_collection.message).to eq(message) }
    end

    it_behaves_like 'a bulk search result collection message', BulkSearch::COMPLETE_STATE, 'Completed'
    it_behaves_like 'a bulk search result collection message', BulkSearch::PROCESSING_STATE, 'Processing'
    it_behaves_like 'a bulk search result collection message', BulkSearch::INITIAL_STATE, 'Your bulk search request has been accepted and is now on a queue waiting to be processed'
    it_behaves_like 'a bulk search result collection message', BulkSearch::FAILED_STATE, 'Failed'
    it_behaves_like 'a bulk search result collection message', BulkSearch::NOT_FOUND_STATE, 'Not found. Do you need to submit a bulk search request again? They expire in 2 hours'
  end

  describe '#http_code' do
    shared_examples_for 'a bulk search result collection http code' do |status, http_code|
      let(:status) { status }

      it { expect(result_collection.http_code).to eq(http_code) }
    end

    it_behaves_like 'a bulk search result collection http code', BulkSearch::COMPLETE_STATE, 200
    it_behaves_like 'a bulk search result collection http code', BulkSearch::PROCESSING_STATE, 202
    it_behaves_like 'a bulk search result collection http code', BulkSearch::INITIAL_STATE, 202
    it_behaves_like 'a bulk search result collection http code', BulkSearch::FAILED_STATE, 500
    it_behaves_like 'a bulk search result collection http code', BulkSearch::NOT_FOUND_STATE, 404
  end

  describe '#status' do
    it { expect(result_collection.status).to eq(status.to_s) }
    it { expect(result_collection.status).to be_a(ActiveSupport::StringInquirer) }
  end
end
