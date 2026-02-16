#!/usr/bin/env ruby
# frozen_string_literal: true

# Validate AI-generated self-texts against the EU reference CSV
#
# Usage:
#   bundle exec rails runner script/validate_ai_builder.rb [chapter]
#   bundle exec rails runner script/validate_ai_builder.rb 01
#   bundle exec rails runner script/validate_ai_builder.rb 84

require 'csv'

CHAPTER = ARGV[0] || '01'
OUTPUT_PATH = Rails.root.join("tmp/validate_ai_builder_ch#{CHAPTER}.csv")

puts '=' * 60
puts "Validating AI self-text builder - Chapter #{CHAPTER}"
puts '=' * 60

TimeMachine.now do
  chapter = Chapter.actual
    .where(Sequel.like(:goods_nomenclature_item_id, "#{CHAPTER}%"))
    .eager(:goods_nomenclature_descriptions)
    .take

  unless chapter
    puts "ERROR: Chapter #{CHAPTER} not found"
    exit 1
  end

  puts "Running MechanicalBuilder for chapter #{CHAPTER}..."
  mechanical_stats = GenerateSelfText::MechanicalBuilder.call(chapter)
  puts "  Mechanical: processed=#{mechanical_stats[:processed]}, skipped_other=#{mechanical_stats[:skipped_other]}"

  puts "Running AiBuilder for chapter #{CHAPTER}..."
  ai_stats = GenerateSelfText::AiBuilder.call(chapter)
  puts "  AI: processed=#{ai_stats[:processed]}, failed=#{ai_stats[:failed]}, needs_review=#{ai_stats[:needs_review]}"

  puts
  puts 'Loading generated self-texts...'

  records = GoodsNomenclatureSelfText
    .where(Sequel.like(:goods_nomenclature_item_id, "#{CHAPTER}%"))
    .where(generation_type: 'ai')
    .all

  puts "Found #{records.size} AI-generated self-texts"

  exact = 0
  different = 0
  no_csv = 0
  needs_review_count = 0

  rows = records.sort_by(&:goods_nomenclature_item_id).map do |record|
    csv_text = SelfTextLookupService.lookup(record.goods_nomenclature_item_id)

    match = if csv_text.nil?
              no_csv += 1
              'no_csv_entry'
            elsif csv_text.downcase.strip == record.self_text.downcase.strip
              exact += 1
              'exact'
            else
              different += 1
              'different'
            end

    needs_review_count += 1 if record.needs_review

    {
      code: record.goods_nomenclature_item_id,
      sid: record.goods_nomenclature_sid,
      ai_self_text: record.self_text,
      csv_self_text: csv_text || '',
      match: match,
      needs_review: record.needs_review,
    }
  end

  # Print side-by-side comparison
  puts
  puts '-' * 80

  rows.each do |row|
    puts "#{row[:code]} (sid: #{row[:sid]})"
    puts "  AI:  #{row[:ai_self_text]}"
    puts "  CSV: #{row[:csv_self_text].presence || '(none)'}"
    puts "  Match: #{row[:match]}#{row[:needs_review] ? ' [NEEDS REVIEW]' : ''}"
    puts
  end

  # Write comparison CSV
  puts "Writing comparison CSV to #{OUTPUT_PATH}..."

  CSV.open(OUTPUT_PATH, 'w') do |csv|
    csv << %w[code sid ai_self_text csv_self_text match needs_review]

    rows.each do |row|
      csv << [row[:code], row[:sid], row[:ai_self_text], row[:csv_self_text], row[:match], row[:needs_review]]
    end
  end

  # Print summary
  puts
  puts '=' * 60
  puts 'Summary'
  puts '=' * 60
  puts "  Total AI-generated: #{records.size}"
  puts "  Exact matches:      #{exact}"
  puts "  Different:          #{different}"
  puts "  No CSV entry:       #{no_csv}"
  puts "  Needs review:       #{needs_review_count}"
  puts
  puts "  Output: #{OUTPUT_PATH}"
end
