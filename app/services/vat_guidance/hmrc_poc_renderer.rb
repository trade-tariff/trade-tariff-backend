require 'cgi'

module VatGuidance
  class HmrcPocRenderer
    def initialize(artifact)
      @artifact = artifact.deep_stringify_keys
    end

    def call
      html = <<~HTML
        <!doctype html>
        <html lang="en">
          <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>VAT guidance journey spike — AI-1146</title>
            <style>
              :root { color-scheme: light; font-family: system-ui, sans-serif; line-height: 1.5; }
              body { margin: 0 auto; max-width: 78rem; padding: 2rem; color: #0b0c0c; }
              header { border-bottom: 4px solid #1d70b8; margin-bottom: 2rem; }
              .warning { border-left: 6px solid #d4351c; background: #f3f2f1; padding: 1rem; }
              .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(12rem, 1fr)); gap: 1rem; }
              .summary div { background: #f3f2f1; padding: 1rem; }
              nav ul { columns: 2; }
              section { margin-top: 2rem; }
              details { border-top: 1px solid #b1b4b6; padding: .75rem 0; }
              summary { cursor: pointer; font-weight: 700; }
              .pending { color: #912b88; font-weight: 700; }
              .recorded { color: #00703c; font-weight: 700; }
              .evidence { border-left: 4px solid #b1b4b6; margin: .5rem 0; padding-left: 1rem; }
              code { overflow-wrap: anywhere; }
              table { border-collapse: collapse; width: 100%; }
              th, td { border: 1px solid #b1b4b6; padding: .5rem; text-align: left; vertical-align: top; }
              th { background: #f3f2f1; }
            </style>
          </head>
          <body>
            <header>
              <h1>VAT guidance journey proof of concept</h1>
              <p>AI-1146 — answer-path connections, dispositions and exhaustion workflow</p>
            </header>
            <div class="warning">
              <strong>Spike only — not approved tax logic.</strong>
              #{h(artifact.fetch('service_position'))}
            </div>
            #{render_summary}
            #{render_upstream_evidence}
            #{render_section_packet_reviews}
            #{render_navigation}
            #{render_connection_proposals}
            #{render_spike_simulation}
            #{render_exhaustion_notes}
            #{render_signpost}
            #{render_path_groups}
            #{render_exclusions}
            <footer><p>Artifact hash: <code>#{h(artifact.fetch('content_sha256'))}</code></p></footer>
          </body>
        </html>
      HTML
      "#{html.lines.map(&:rstrip).join("\n")}\n"
    end

  private

    attr_reader :artifact

    def render_summary
      summary = artifact.fetch('summary')
      items = {
        'Answer paths' => summary.fetch('answer_paths'),
        'Section packets accounted' => summary.fetch('section_packets_accounted_for'),
        'Rule connection paths' => summary.fetch('rule_connection_paths'),
        'Pinned measure proposals' => summary.fetch('pinned_measure_proposals'),
        'Approved connections' => summary.fetch('approved_measure_connections'),
        'Synthetic quote approvals' => summary.fetch('synthetic_quote_support_approvals'),
        'Composed spike commodities' => summary.fetch('composed_spike_commodities'),
        'Dispositions' => summary.fetch('dispositions'),
        'Pending quote reviews' => summary.fetch('pending_quote_support_reviews'),
      }
      cards = items.map { |label, value| "<div><strong>#{h(value)}</strong><br>#{h(label)}</div>" }.join
      "<section><h2>Coverage</h2><div class=\"summary\">#{cards}</div></section>"
    end

    def render_section_packet_reviews
      records = artifact.fetch('section_packet_reviews').map do |record|
        journey_ids = record.fetch('journey_ids').presence&.join(', ') || 'No contract-safe standalone tree'
        <<~HTML
          <details>
            <summary>#{h(record.fetch('status'))} — <code>#{h(record.fetch('packet_id'))}</code></summary>
            <p>Journeys: #{h(journey_ids)}</p>
            <p>#{h(record.fetch('finding'))}</p>
            <p>Source packet hash: <code>#{h(record.fetch('source_packet_sha256'))}</code></p>
          </details>
        HTML
      end
      records = records.join
      <<~HTML
        <section id="section-packet-reviews">
          <h2>All-section packet accounting</h2>
          <p>Every captured section packet is either represented by a curated journey or retains an explicit no-safe-tree disposition.</p>
          #{records}
        </section>
      HTML
    end

    def render_connection_proposals
      proposals = artifact.fetch('measure_connection_proposals').map do |proposal|
        snapshot = proposal.fetch('measure_snapshot')
        evidence_against = proposal.fetch('evidence_against')
        full_cohort = snapshot.fetch('full_inherited_declarable_cohort', snapshot.fetch('declarable_commodity_codes'))
        <<~HTML
          <details>
            <summary><code>#{h(snapshot.fetch('origin_goods_nomenclature'))}</code> cohort → #{h(snapshot.fetch('additional_code'))} measure #{h(snapshot.fetch('measure_id'))}</summary>
            <p>Status: <span class="pending">#{h(proposal.fetch('status'))}</span></p>
            <p>Rule path: <code>#{h(proposal.fetch('answer_path_id'))}</code></p>
            <p>Snapshot: #{h(snapshot.fetch('snapshot_date'))}; inherited from <code>#{h(snapshot.fetch('origin_goods_nomenclature'))}</code>; #{h(full_cohort.size)} declarable descendants reviewed; #{h(snapshot.fetch('declarable_commodity_codes').size)} explicitly connected in this Spike.</p>
            <p><strong>Wrong-relief challenge:</strong> #{h(evidence_against.fetch('wrong_relief_persona'))}</p>
            <p>#{h(evidence_against.fetch('assessment'))}</p>
            <p>Pairing approval: <span class="pending">#{h(proposal.dig('pairing_approval', 'status'))}</span>; quote support: <span class="pending">#{h(proposal.dig('quote_support_approval', 'status'))}</span>.</p>
          </details>
        HTML
      end
      proposals = proposals.join
      <<~HTML
        <section id="measure-proposals">
          <h2>Pinned measure connection proposals</h2>
          <p>These records prove the rule-path × tariff-measure join for the spike. Availability does not prove eligibility, and no proposal is approved.</p>
          #{proposals}
        </section>
      HTML
    end

    def render_spike_simulation
      fixture = artifact.fetch('synthetic_spike_reviews')
      compositions = artifact.fetch('composed_commodity_journeys').map do |composition|
        exhaustion = composition.fetch('exhaustion_note')
        resolution_counts = composition.fetch('resolved_answer_paths').map { |path| path.fetch('treatment') }.tally
        routes = composition.fetch('resolved_answer_paths').map { |route| render_composed_route(route) }.join
        <<~HTML
          <details>
            <summary><code>#{h(composition.fetch('commodity_code'))}</code> — #{h(composition.fetch('status'))}</summary>
            <p>Rule order: <code>#{h(composition.fetch('rule_order').join(' → '))}</code></p>
            <p>Resolved paths: #{h(resolution_counts.sort.map { |treatment, count| "#{treatment}=#{count}" }.join(', '))}. No fallthrough remains visible.</p>
            <p>Applicable and covered non-standard measures: <code>#{h(exhaustion.fetch('covered_measure_ids').join(', '))}</code>.</p>
            <p>Standard-by-default after every ordered rule declines: <strong>#{h(exhaustion.fetch('standard_by_default_permitted_after_all_rules_decline'))}</strong>.</p>
            <h3>Walkable composed routes</h3>
            #{routes}
          </details>
        HTML
      end
      compositions = compositions.join
      <<~HTML
        <section id="spike-simulation">
          <h2>Synthetic end-to-end composition simulation</h2>
          <div class="warning"><strong>Not a domain approval.</strong> #{h(fixture.fetch('warning'))}</div>
          <p>Review fixture: <code>#{h(fixture.fetch('review_mode'))}</code>; reviewer: <code>#{h(fixture.fetch('reviewer'))}</code>.</p>
          #{compositions}
        </section>
      HTML
    end

    def render_composed_route(route)
      rendered_steps = []
      route.fetch('steps').each_with_index do |step, index|
        rendered_steps << "<li><strong>#{h(index + 1)}. #{h(step.fetch('question'))}</strong><br>Answer: #{h(step.fetch('answer'))}</li>"
      end
      steps = rendered_steps.join
      measures = route.fetch('measure_ids').presence&.join(', ') || 'none'
      <<~HTML
        <article>
          <h4>#{h(route.fetch('treatment'))} — <code>#{h(route.fetch('id'))}</code></h4>
          <ol>#{steps}</ol>
          <p>Resolution: #{h(route.fetch('resolution'))}; measures: <code>#{h(measures)}</code>.</p>
          <p>Rule paths: <code>#{h(route.fetch('component_path_ids').join(' → '))}</code>.</p>
        </article>
      HTML
    end

    def render_navigation
      groups = grouped_paths
      links = (groups.map do |key, paths|
        "<li><a href=\"##{h(anchor(key))}\">#{h(key)} (#{paths.size} paths)</a></li>"
      end).join
      "<nav aria-label=\"Journey groups\"><h2>Browse journeys</h2><ul>#{links}</ul></nav>"
    end

    def render_upstream_evidence
      evidence = artifact.fetch('upstream_evidence')
      graph = evidence.fetch('context_graph')
      packets = evidence.fetch('context_packets')
      journeys = evidence.fetch('question_journeys')
      tariff = evidence.fetch('tariff_snapshot')
      <<~HTML
        <section id="upstream-evidence">
          <h2>Evidence lineage</h2>
          <p>This PoC is bound to the reviewed graph, context packets and question journeys.</p>
          <table>
            <thead><tr><th>Artifact</th><th>Coverage</th><th>SHA-256</th></tr></thead>
            <tbody>
              <tr><td>Context graph</td><td>#{h(graph.dig('summary', 'sections_captured'))} sections; #{h(graph.dig('summary', 'reference_edges'))} references; #{h(graph.dig('summary', 'unresolved_references'))} unresolved retained</td><td><code>#{h(graph.fetch('content_sha256'))}</code></td></tr>
              <tr><td>Context packets</td><td>#{h(packets.dig('summary', 'packets'))} notice packets; #{h(packets.dig('summary', 'commodity_packets'))} commodity packets</td><td><code>#{h(packets.fetch('content_sha256'))}</code></td></tr>
              <tr><td>Question journeys</td><td>#{h(journeys.dig('summary', 'journeys'))} journeys; #{h(journeys.dig('summary', 'valid_journeys'))} valid</td><td><code>#{h(journeys.fetch('content_sha256'))}</code></td></tr>
              <tr><td>Tariff snapshot</td><td>#{h(tariff.fetch('measures'))} non-standard measures; #{h(tariff.fetch('declarable_measure_pairings'))} inherited declarable pairings; #{h(tariff.fetch('independently_verified_commodities'))} independently verified composition commodities; #{h(tariff.fetch('snapshot_date'))}</td><td><code>#{h(tariff.fetch('content_sha256'))}</code></td></tr>
            </tbody>
          </table>
        </section>
      HTML
    end

    def render_exhaustion_notes
      rows = (artifact.fetch('commodity_exhaustion_notes').map do |note|
        <<~ROW
          <tr>
            <td><code>#{h(note.fetch('commodity_code'))}</code></td>
            <td class="recorded">#{h(note.fetch('status'))}</td>
            <td>#{h(note.fetch('applicable_non_standard_measure_ids').join(', '))}</td>
            <td>#{h(note.fetch('standard_by_default_permitted_after_all_rules_decline'))}</td>
          </tr>
        ROW
      end).join
      <<~HTML
        <section id="exhaustion">
          <h2>Commodity exhaustion notes</h2>
          <p>Each row must cover the exact applicable non-standard measure set before standard-by-default is permitted.</p>
          <table><thead><tr><th>Commodity</th><th>Status</th><th>Applicable and covered measures</th><th>Standard after exhaustion</th></tr></thead><tbody>#{rows}</tbody></table>
        </section>
      HTML
    end

    def render_signpost
      items = (artifact.fetch('signpost_assessments').map do |item|
        "<li><code>#{h(item.fetch('commodity_code'))}</code> — #{h(item.fetch('label'))}: #{h(item.fetch('finding'))}</li>"
      end).join
      "<section><h2>Wrong-relief signpost</h2><ul>#{items}</ul></section>"
    end

    def render_path_groups
      (grouped_paths.map do |key, paths|
        rendered_paths = paths.map { |path| render_path(path) }.join
        "<section id=\"#{h(anchor(key))}\"><h2>#{h(key)}</h2>#{rendered_paths}</section>"
      end).join
    end

    def render_path(path)
      terminal = path.fetch('terminal')
      review = path.fetch('review')
      steps = (path.fetch('steps').map.with_index do |step, index|
        <<~HTML
          <li>
            <strong>#{index + 1}. #{h(step.fetch('question'))}</strong><br>
            Answer: #{h(step.fetch('answer'))}
            #{render_evidence(step.fetch('evidence'))}
          </li>
        HTML
      end).join
      terminal_label = terminal['type'] == 'outcome' ? terminal.fetch('treatment') : 'internal composition gate'
      status_class = review['status'] == 'spike_recorded' ? 'recorded' : 'pending'
      review_detail = if review['kind'] == 'connection_candidate'
                        "Candidate #{review.fetch('additional_code')}; measure binding #{review.fetch('measure_binding_status')}."
                      else
                        review.fetch('reason', review.fetch('disposition'))
                      end
      terminal_evidence = terminal['evidence'] ? render_evidence(terminal.fetch('evidence')) : ''
      <<~HTML
        <details>
          <summary>#{h(terminal_label)} — <code>#{h(path.fetch('id'))}</code></summary>
          <ol>#{steps}</ol>
          <p>Terminal: <strong>#{h(terminal_label)}</strong></p>
          #{terminal_evidence}
          <p>Review: <span class="#{status_class}">#{h(review.fetch('status'))}</span> — #{h(review_detail)}</p>
          <p>Quote support: <span class="pending">#{h(review.dig('quote_support', 'status'))}</span></p>
        </details>
      HTML
    end

    def render_exclusions
      items = (artifact.fetch('exclusions').map do |item|
        exclusion = item.fetch('exclusion')
        <<~HTML
          <details>
            <summary>#{h(item.fetch('journey_id'))} — #{h(exclusion.fetch('id'))}</summary>
            <p>#{h(exclusion.fetch('reason'))}</p>
            #{render_evidence(exclusion.fetch('evidence'))}
            <p>Quote support: <span class="pending">pending_domain_review</span></p>
          </details>
        HTML
      end).join
      "<section><h2>Assessment and apportionment exclusions</h2>#{items}</section>"
    end

    def render_evidence(evidence)
      quote = evidence.fetch('quote')
      node_id = evidence.fetch('node_id')
      url = source_url(node_id)
      source = url ? "<a href=\"#{h(url)}\">#{h(node_id)}</a>" : h(node_id)
      "<div class=\"evidence\"><q>#{h(quote)}</q><br>Source: #{source}</div>"
    end

    def source_url(node_id)
      match = node_id.match(%r{\Adocument:(/guidance/[a-z0-9-]+(?:#[a-z0-9-]+)?)\z})
      "https://www.gov.uk#{match[1]}" if match
    end

    def grouped_paths
      @grouped_paths ||= (artifact.fetch('answer_paths').group_by do |path|
        scope = path.fetch('scope')
        scope['type'] == 'commodity' ? "Commodity #{scope.fetch('commodity_code')} — #{scope.fetch('label')}" : "VAT Notice #{scope.fetch('notice_number')} — #{scope.fetch('label')}"
      end).sort.to_h
    end

    def anchor(value) = value.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/\A-|-+\z/, '')
    def h(value) = CGI.escapeHTML(value.to_s)
  end
end
