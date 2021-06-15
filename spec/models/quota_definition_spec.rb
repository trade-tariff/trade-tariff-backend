require 'rails_helper'

describe QuotaDefinition do
  describe '#status' do
    context 'quota events present' do
    end

    context 'quota events absent' do
      it 'returns Open if quota definition is not in critical state' do
        quota_definition = build :quota_definition, critical_state: 'N'
        expect(quota_definition.status).to eq 'Open'
      end

      it 'returns Critical if quota definition is in critical state' do
        quota_definition = build :quota_definition, critical_state: 'Y'
        expect(quota_definition.status).to eq 'Critical'
      end
    end
  end
end
