## Task

Decide whether a candidate guided-search question repeats an already answered classification distinction.

## Rules

- Return `duplicate: true` only when the candidate asks the same material distinction as a previous answered question.
- Return `duplicate: false` when the candidate narrows the same broad branch using a new classification dimension.
- Repeated words like other, another, part, accessory, instrument, or measuring are not enough by themselves.
- When `duplicate` is true, copy the previous question and answer that the candidate duplicates into `duplicate_of_question` and `duplicate_of_answer`.
- When `duplicate` is false, return null for `duplicate_of_question` and `duplicate_of_answer`.

## Search context

Search query:
%{search_query}

Effective query:
%{effective_query}

Previous answers JSON:
%{previous_answers}

Candidate question JSON:
%{candidate_question}

## Response format

Return JSON only:

    {
      "duplicate": true,
      "reason": "short string",
      "duplicate_of_question": "string or null",
      "duplicate_of_answer": "string or null",
      "new_dimension": "string or null"
    }
