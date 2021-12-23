require 'rails_helper'

RSpec.describe ApiConstraints do
  describe '#matches?' do
    subject(:constraint) { described_class.new(version: constraint_version) }

    before do
      allow(described_class).to receive(:default_version)
                                .and_return(default_version)
    end

    # rubocop:disable RSpec/MultipleMemoizedHelpers
    let(:bare_req) { OpenStruct.new(headers: {}) }
    let(:no_v_req) { OpenStruct.new(headers: { 'Accept' => 'application/json' }) }
    let(:v1_req) { OpenStruct.new(headers: { 'Accept' => 'application/vnd.uktt.v1' }) }
    let(:v2_req) { OpenStruct.new(headers: { 'Accept' => 'application/vnd.uktt.v2' }) }
    let(:v9_req) { OpenStruct.new(headers: { 'Accept' => 'application/vnd.uktt.v9' }) }

    context 'with v1 default version' do
      let(:default_version) { '1' }

      context 'for v1 constraint' do
        let(:constraint_version) { 1 }

        it { expect(constraint.matches?(bare_req)).to be true }
        it { expect(constraint.matches?(no_v_req)).to be true }
        it { expect(constraint.matches?(v1_req)).to be true }
        it { expect(constraint.matches?(v2_req)).to be false }
        it { expect(constraint.matches?(v9_req)).to be false }
      end

      context 'for v2 constraint' do
        let(:constraint_version) { 2 }

        it { expect(constraint.matches?(bare_req)).to be false }
        it { expect(constraint.matches?(no_v_req)).to be false }
        it { expect(constraint.matches?(v1_req)).to be false }
        it { expect(constraint.matches?(v2_req)).to be true }
        it { expect(constraint.matches?(v9_req)).to be false }
      end
    end

    context 'with v2 default version' do
      let(:default_version) { '2' }

      context 'for v1 constraint' do
        let(:constraint_version) { 1 }

        it { expect(constraint.matches?(bare_req)).to be false }
        it { expect(constraint.matches?(no_v_req)).to be false }
        it { expect(constraint.matches?(v1_req)).to be true }
        it { expect(constraint.matches?(v2_req)).to be false }
        it { expect(constraint.matches?(v9_req)).to be false }
      end

      context 'for v2 constraint' do
        let(:constraint_version) { 2 }

        it { expect(constraint.matches?(bare_req)).to be true }
        it { expect(constraint.matches?(no_v_req)).to be true }
        it { expect(constraint.matches?(v1_req)).to be false }
        it { expect(constraint.matches?(v2_req)).to be true }
        it { expect(constraint.matches?(v9_req)).to be false }
      end
    end
    # rubocop:enable RSpec/MultipleMemoizedHelpers
  end
end
