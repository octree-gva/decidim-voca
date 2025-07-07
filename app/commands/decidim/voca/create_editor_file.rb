# frozen_string_literal: true

module Decidim
  module Voca
    class CreateEditorFile < Command
      # Creates a blueprint.
      #
      # form - The form with the data.
      def initialize(form)
        @form = form
      end
      

      # Executes the command. Broadcasts these events:
      #
      # - :ok when everything is valid
      # - :invalid if the form wasn't valid and we couldn't proceed.
      #
      # Returns nothing.
      def call
        return broadcast(:invalid) if form.invalid?

        image = EditorFile.new(
          path: form.path,
          decidim_author_id: form.current_user.id,
          organization: form.organization,
          file: form.file
        )

        image.save!
        broadcast(:ok, image)
      end

      attr_reader :form
    end
  end
end
