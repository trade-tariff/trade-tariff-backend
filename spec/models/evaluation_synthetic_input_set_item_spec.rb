require 'rails_helper'

RSpec.describe EvaluationSyntheticInputSetItem do
  it 'requires a set, a synthetic ATaR, a query, oracle text and an expected code' do
    item = build(
      :evaluation_synthetic_input_set_item,
      evaluation_synthetic_input_set: nil, synthetic_atar_id: nil, query: nil, oracle_text: nil, expected_code: nil,
    )

    expect(item.valid?).to be false
    expect(item.errors[:set_id]).to be_present
    expect(item.errors[:synthetic_atar_id]).to be_present
    expect(item.errors[:query]).to be_present
    expect(item.errors[:oracle_text]).to be_present
    expect(item.errors[:expected_code]).to be_present
  end

  # Sequel::DatabaseError, not the more specific Sequel::ForeignKeyConstraintViolation: an
  # ON DELETE RESTRICT violation is reported under a different Postgres error code
  # (restrict_violation) than a plain foreign-key violation, and Sequel only maps the latter to
  # the specific subclass. Confirmed this varies by Postgres version even for the same real
  # violation -- Postgres 15 (local) raises ForeignKeyConstraintViolation here, Postgres 18 (CI)
  # raises the generic DatabaseError for the exact same restriction. Postgres also reworded the
  # message itself between versions ("is still referenced" on 15, "is referenced" on 18), hence
  # the optional "still". Asserting on the message keeps this test about the actual guarantee
  # (the referenced row blocks the delete) rather than an incidental, version-dependent detail.
  it 'refuses to delete a synthetic ATaR that a set item still references' do
    synthetic_atar = create(:tariff_knowledge_synthetic_atar)
    create(:evaluation_synthetic_input_set_item, synthetic_atar_id: synthetic_atar.id)

    expect { synthetic_atar.destroy }.to raise_error(Sequel::DatabaseError, /is (still )?referenced from table "evaluation_synthetic_input_set_items"/)
  end

  it 'is deleted when its set is deleted' do
    item = create(:evaluation_synthetic_input_set_item)
    set = item.evaluation_synthetic_input_set

    expect { set.destroy }.to change(described_class, :count).by(-1)
  end
end
