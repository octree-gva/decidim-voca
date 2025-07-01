# frozen_string_literal: true

Deface::Override.new(
  virtual_path: "decidim/proposals/admin/proposals/index",
  name: "show_votes_th",
  replace_contents: "erb[silent]:contains('if current_settings.votes_enabled?')",
  closing_selector: "erb[silent]:contains('end')",
  text: "<th>
          <%= sort_link(query, :proposal_votes_count, t('models.proposal.fields.votes_on_going', scope: 'decidim.proposals') ) %>
        </th>
        <% else %>
        <th>
          <%= sort_link(query, :proposal_votes_count, t('models.proposal.fields.votes', scope: 'decidim.proposals') ) %>
        </th>"
)

Deface::Override.new(
  virtual_path: "decidim/proposals/admin/proposals/_proposal-tr",
  name: "show_votes_tr",
  replace: "erb[silent]:contains('if current_settings.votes_enabled?')",
  closing_selector: "erb[silent]:contains('end')",
  text: "<td>
          <%= proposal.proposal_votes_count %>
        </td>"
)