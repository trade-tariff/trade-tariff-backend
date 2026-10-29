require 'rails_helper'

RSpec.describe EvaluationSyntheticInputSet do
  describe 'validations' do
    subject(:set) { build(:evaluation_synthetic_input_set, **attrs) }

    let(:attrs) { {} }

    it 'is valid with the factory defaults' do
      expect(set).to be_valid
    end

    %i[name requested_size actual_size].each do |column|
      context "when #{column} is missing" do
        let(:attrs) { { column => nil } }

        it 'is invalid' do
          expect(set).not_to be_valid
          expect(set.errors[column]).to be_present
        end
      end
    end

    context 'when the name is already used' do
      before { create(:evaluation_synthetic_input_set, name: 'Set A') }

      let(:attrs) { { name: 'Set A' } }

      it 'is invalid' do
        expect(set).not_to be_valid
        expect(set.errors[:name]).to include('is already taken')
      end
    end

    [0, -3].each do |size|
      context "when requested_size is #{size}" do
        let(:attrs) { { requested_size: size } }

        it 'is invalid' do
          expect(set).not_to be_valid
          expect(set.errors[:requested_size]).to eq(['must be greater than 0'])
        end
      end
    end
  end

  it 'holds the items created for it' do
    set = create(:evaluation_synthetic_input_set)
    item = create(:evaluation_synthetic_input_set_item, evaluation_synthetic_input_set: set)

    expect(set.evaluation_synthetic_input_set_items).to eq([item])
  end

  it 'knows the experiments that use it' do
    set = create(:evaluation_synthetic_input_set)
    experiment = create(:evaluation_experiment, synthetic_input_set_id: set.id)
    create(:evaluation_experiment)

    expect(set.evaluation_experiments).to eq([experiment])
  end
end
