module VatGuidance
  module QuestionJourneyContract
    SCHEMA_VERSION = 1
    TREATMENTS = {
      'standard' => { 'additional_code' => nil, 'display' => 'rate_from_tariff_measure' },
      'reduced' => { 'additional_code' => 'VATR', 'display' => 'rate_from_tariff_measure' },
      'zero' => { 'additional_code' => 'VATZ', 'display' => 'rate_from_tariff_measure' },
      'exempt' => { 'additional_code' => 'VATE', 'display' => 'no VAT chargeable' },
    }.freeze
    OUTCOME_BASES = %w[explicit_guidance exhaustive_default].freeze
    NEXT_TYPES = %w[question outcome fallthrough].freeze
    RATE_KEY = /(?:\A|_)(?:rate|percentage|percent|vat_rate)(?:\z|_)/i
    RATE_VALUE = /%|\bper\s+cent\b|\bpercent(?:age)?\b/i

    def self.generation_prompt
      <<~PROMPT
        Generate a VAT guidance question journey as JSON only.

        Hard contract:
        - Every trader answer must lead to another question or to exactly one treatment:
          standard, reduced, zero, or exempt. A rule that cannot decide may use an internal,
          non-trader-visible fallthrough so a later composition step can continue to the next rule.
        - Never expose undecided, unknown, fall-through, manual review, or a percentage as an outcome.
        - Internal rule fall-through must use a declared, non-trader-visible module boundary that the
          later composer is required to resolve. Standard-by-default is permitted only after the full
          declared relief set has been traversed and every relief answer on that path has declined.
        - Exclude assessment, apportionment, and mixed-treatment cases as spike findings instead of
          inventing a single treatment.
        - Every question and outcome must carry an exact verbatim quote plus the packet node_id,
          guide_key, and section_key where the quote occurs. Scope must match the packet source.
          Notice scope has exactly type, notice_number, and label; commodity scope has exactly type,
          chapter, commodity_code, and label. The label must equal the packet source heading.
        - Store treatments, never numerical rates. Runtime code will read the current percentage from
          the matching tariff measure. Zero and exempt are distinct treatments.

        Return one JSON object with exactly these fields:
        journey_id, source_packet_id, scope, relief_rule_ids, composition_required,
        fallthrough_targets, root_question_id, questions, outcomes, and exclusions. The optional
        comparison_role field is permitted only for the declared catering comparison. Each question
        has id, prompt, evidence, and answers. Each answer has id, label, and next, and may carry
        relief_disposition. relief_disposition is qualified for a relief-granting answer and declined
        for a declining relief branch; every fallthrough must explicitly be declined. A question or
        outcome next object has exactly type and id. A fallthrough next object has exactly type, id,
        trader_visible, and reason: trader_visible must be false and reason must explain which rule was
        declined. Each outcome has id, treatment, basis, optional relief_question_ids, and evidence.
        Evidence has quote, node_id, guide_key, and section_key. Do not add prose outside the JSON object.
      PROMPT
    end
  end
end
