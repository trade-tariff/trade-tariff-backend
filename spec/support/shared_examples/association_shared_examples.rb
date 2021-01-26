require 'rails_helper'

shared_examples_for 'one to one to' do |associated_object, eager_load_association = associated_object|
  @source_record =  :"#{described_class.to_s.underscore}"
  let!(:primary_key)               { associated_object.to_s.classify.constantize.primary_key }
  let!(:left_primary_key)          { primary_key }
  let!(:right_primary_key)         { primary_key }
  let!(:left_association)          do
    if left_primary_key.is_a?(Array)
      left_primary_key.each_with_object({}) do |key_name, memo|
        memo.merge!(Hash[key_name, send(key_name)])
      end
    else
      Hash[left_primary_key, send(left_primary_key)]
    end
  end
  let!(:right_association) do
    if right_primary_key.is_a?(Array)
      right_primary_key.each_with_object({}) do |key_name, memo|
        memo.merge!(Hash[key_name, send(key_name)])
      end
    else
      Hash[right_primary_key, send(right_primary_key)]
    end
  end
  let!(:source_record)             { :"#{described_class.to_s.underscore}" }
  let!(:"#{associated_object}1")   { create associated_object, { validity_start_date: Date.current.ago(3.years) }.merge(right_association) }
  let!(:"#{associated_object}2")   { create associated_object, { validity_start_date: Date.current.ago(5.years) }.merge(right_association) }
  let!(@source_record)             { create source_record, left_association }

  context 'direct loading' do
    it "loads correct #{associated_object.to_s.humanize} respecting given actual time" do
      TimeMachine.now do
        expect(
          send(source_record).send(associated_object).pk,
        ).to eq send(:"#{associated_object}1").pk
      end
    end

    it "loads correct #{associated_object.to_s.humanize} respecting given time" do
      TimeMachine.at(1.year.ago) do
        expect(
          send(source_record).send(associated_object).pk,
        ).to eq send(:"#{associated_object}1").pk
      end
    end
  end
end
