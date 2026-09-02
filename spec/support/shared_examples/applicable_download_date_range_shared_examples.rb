RSpec.shared_examples_for 'an applicable download date range' do |update_factory|
  let(:today) { Time.zone.today }
  let(:pending_issue_date) { today - 21.days }
  let(:applied_issue_date) { today - 22.days }
  let(:failed_issue_date) { today - 23.days }

  context 'when choosing a pending update older than the default download from date' do
    before do
      create(update_factory, :pending, example_date: pending_issue_date)
      create(update_factory, :applied, example_date: applied_issue_date)
      create(update_factory, :failed, example_date: failed_issue_date)
    end

    it { is_expected.to eq(pending_issue_date..today) }
  end

  context 'when choosing a applied update older than the default download from date' do
    before do
      create(update_factory, :applied, example_date: applied_issue_date)
      create(update_factory, :failed, example_date: failed_issue_date)
    end

    it { is_expected.to eq(applied_issue_date..today) }
  end

  context 'when choosing a failed update older than the default download from date' do
    before do
      create(update_factory, :failed, example_date: failed_issue_date)
    end

    it { is_expected.to eq(failed_issue_date..today) }
  end

  context 'when there is an update issued 20 days ago or less' do
    let(:pending_issue_date) { today - 20.days }

    before do
      create(update_factory, :pending, example_date: pending_issue_date)
    end

    it { is_expected.to eq(pending_issue_date..today) }
  end

  context 'when there are no updates yet' do
    it { is_expected.to eq(initial_date..today) }
  end
end# frozen_string_literal: true

