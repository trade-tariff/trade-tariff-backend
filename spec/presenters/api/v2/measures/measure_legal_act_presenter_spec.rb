RSpec.describe Api::V2::Measures::MeasureLegalActPresenter do
  subject(:presenter) { described_class.new(regulation, measure) }

  let(:regulation) { create(:base_regulation, base_regulation_id: '1234567') }
  let(:measure) { create(:measure) }

  let(:eu_regulation) do
    {
      code: '14567/23',
      url: 'http://eur-lex.europa.eu/search.html?',
      description: 'This is some explanatory information text',
    }
  end

  let(:uk_regulation) do
    {
      code: 'S.I. 2019/16',
      url: 'https://www.legislation.gov.uk/uksi/2019/16',
      description:
        'The Leghold Trap and Pelt Imports (Amendment etc.) (EU Exit) Regulations 2019',
    }
  end

  describe '#regulation_id' do
    it 'maps to the models internal id' do
      expect(presenter.regulation_id).to eql(regulation.base_regulation_id)
    end
  end

  describe 'published_date' do
    subject { presenter.published_date }

    context 'without regulation present' do
      let(:regulation) { nil }

      it { is_expected.to be_nil }
    end

    context 'with legal act' do
      let(:regulation) do
        create(:base_regulation, published_date: Date.yesterday)
      end

      it { is_expected.to eql(Date.yesterday) }
    end

    context 'with legal act without published_date field' do
      let(:regulation) { create(:measure_partial_temporary_stop) }

      it { is_expected.to be_nil }
    end
  end

  context 'for XI service' do
    before { allow(TradeTariffBackend).to receive(:service).and_return('xi') }

    describe '#regulation_code' do
      it { expect(presenter.regulation_code).to eql(eu_regulation[:code]) }
    end

    describe '#regulation_url' do
      it { expect(presenter.regulation_url).to start_with(eu_regulation[:url]) }
    end

    describe '#description' do
      it { expect(presenter.description).to eql(eu_regulation[:description]) }
    end

    context 'with regulation without an information_text field' do
      let(:regulation) do
        create(:measure_partial_temporary_stop,
               partial_temporary_stop_regulation_id: '1234567')
      end

      describe '#regulation_code' do
        it { expect(presenter.regulation_code).to eql(eu_regulation[:code]) }
      end

      describe '#regulation_url' do
        it { expect(presenter.regulation_url).to match(eu_regulation[:url]) }
      end

      describe '#description' do
        it { expect(presenter.description).to be_nil }
      end
    end
  end

  context 'for UK service' do
    before { allow(TradeTariffBackend).to receive(:service).and_return('uk') }

    context 'when before 01 Jan 2021' do
      describe '#regulation_code' do
        it { expect(presenter.regulation_code).to eql(eu_regulation[:code]) }
      end

      describe '#regulation_url' do
        it { expect(presenter.regulation_url).to start_with(eu_regulation[:url]) }
      end

      describe '#description' do
        it { expect(presenter.description).to eql(eu_regulation[:description]) }
      end
    end

    context 'when after 01 Jan 2021' do
      let(:regulation) { create(:base_regulation, :uk_concatenated_regulation) }

      describe '#regulation_code' do
        it { expect(presenter.regulation_code).to eql(uk_regulation[:code]) }
      end

      describe '#regulation_url' do
        it { expect(presenter.regulation_url).to eql(uk_regulation[:url]) }
      end

      describe '#description' do
        it { expect(presenter.description).to eql(uk_regulation[:description]) }
      end
    end

    context 'when after 01 Jan 2021 with null information_text field' do
      let(:regulation) do
        create(:base_regulation, :uk_concatenated_regulation,
               base_regulation_id: '1234567',
               information_text: nil)
      end

      describe '#regulation_code' do
        it { expect(presenter.regulation_code).to eql(eu_regulation[:code]) }
      end

      describe '#regulation_url' do
        it { expect(presenter.regulation_url).to eql('') }
      end

      describe '#description' do
        it { expect(presenter.description).to be_nil }
      end
    end

    context 'when after 01 Jan 2021 with invalid information_text field' do
      let(:regulation) do
        create(:base_regulation, :uk_concatenated_regulation,
               base_regulation_id: '1234567',
               uk_regulation_code: nil)
      end

      describe '#regulation_code' do
        it { expect(presenter.regulation_code).to eql(eu_regulation[:code]) }
      end

      describe '#regulation_url' do
        it { expect(presenter.regulation_url).to eql('') }
      end

      describe '#description' do
        it { expect(presenter.description).to be_nil }
      end
    end

    context 'with regulation without an information_text field' do
      context 'for date from 01 Jan 2021' do
        let(:regulation) do
          create(:measure_partial_temporary_stop,
                 partial_temporary_stop_regulation_id: '1234567')
        end

        describe '#regulation_code' do
          it { expect(presenter.regulation_code).to eql(eu_regulation[:code]) }
        end

        describe '#regulation_url' do
          it { expect(presenter.regulation_url).to match(eu_regulation[:url]) }
        end

        describe '#description' do
          it { expect(presenter.description).to be_nil }
        end
      end

      context 'for date 01 Jan 2021' do
        let(:regulation) do
          create(:measure_partial_temporary_stop,
                 partial_temporary_stop_regulation_id: '1234567',
                 partial_temporary_stop_regulation_officialjournal_number: '1',
                 partial_temporary_stop_regulation_officialjournal_page: 1)
        end

        describe '#regulation_code' do
          it { expect(presenter.regulation_code).to eql(eu_regulation[:code]) }
        end

        describe '#regulation_url' do
          it { expect(presenter.regulation_url).to eql('') }
        end

        describe '#description' do
          it { expect(presenter.description).to be_nil }
        end
      end
    end
  end

  context 'when showing reduced information' do
    context 'with regulation id of IVY99990' do
      let(:regulation) { create(:base_regulation, base_regulation_id: 'IYY99990') }

      it { is_expected.to have_attributes(regulation_code: '') }
      it { is_expected.to have_attributes(regulation_url: '') }
      it { is_expected.to have_attributes(description: nil) }
    end

    context 'with measure type 305' do
      let(:measure) { create(:measure, measure_type_id: '305') }

      it { is_expected.to have_attributes(regulation_code: '') }
      it { is_expected.to have_attributes(regulation_url: '') }
      it { is_expected.to have_attributes(description: nil) }
    end

    context 'with measure type 306' do
      let(:measure) { create(:measure, measure_type_id: '306') }

      it { is_expected.to have_attributes(regulation_code: '') }
      it { is_expected.to have_attributes(regulation_url: '') }
      it { is_expected.to have_attributes(description: nil) }
    end
  end
end
