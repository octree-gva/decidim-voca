# frozen_string_literal: true

# Fix: can drag'n drop marker on map when creating a new proposal

Deface::Override.new(
  virtual_path: "decidim/proposals/proposals/_edit_form_fields",
  name: "fix_map_new_proposal",
  replace: "erb[loud]:contains('proposal_preview_data_for_map')",
  text: <<~ERB
    <%
      map_data = if new_proposal
        {
          type: "drag-marker",
          # Dummy marker, to be removed when the user click on suggestions
          marker: {
            latitude: 40.416775,
            longitude: 4.379229,
            address: "Calle de la Princesa, 1, 28001 Madrid, Spain",
            icon: icon("chat-new-line", width: 40, height: 70, remove_icon_class: true)
          }
        }
      else
        proposal_preview_data_for_map(@proposal)
      end
    %>
    <%= dynamic_map_for(map_data) %>
  ERB
)
