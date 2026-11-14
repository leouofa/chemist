# frozen_string_literal: true

class ChemicalClassesController < ApplicationController
  def populate
    PopulateChemicalClassesJob.perform_later

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "populate_controls",
          partial: "pages/populate_controls",
          locals: {
            target_id: "populate_controls",
            action_path: populate_chemical_classes_path,
            idle_label: "Populate Chemical Classes",
            running_label: "Discovering Chemical Classes...",
            running: true,
            status_message: "Discovering major chemical classes with LLM...",
            status_kind: :info
          }
        )
      end
      format.html { redirect_to root_path, notice: "Chemical class discovery queued." }
    end
  end
end
