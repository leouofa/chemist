# frozen_string_literal: true

class FunctionalGroupsController < ApplicationController
  include EmbeddableActions

  def show
    @functional_group = FunctionalGroup.includes(molecule: :chemical_class).find(params[:id])

    respond_to do |format|
      format.html
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(
          "cluster_modal",
          partial: "functional_groups/modal",
          locals: { functional_group: @functional_group }
        )
      end
    end
  end

  def generate_embedding
    @functional_group = FunctionalGroup.find(params[:id])
    enqueue_embedding_generation(@functional_group)
  end

  def populate
    PopulateFunctionalGroupsJob.perform_later

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "populate_all_functional_groups_controls",
          partial: "pages/populate_controls",
          locals: {
            target_id: "populate_all_functional_groups_controls",
            action_path: populate_functional_groups_path,
            idle_label: "Discover Atoms / Functional Groups",
            running_label: "Discovering Atoms / Functional Groups...",
            running: true,
            status_message: "Discovering functional groups across molecules with LLM...",
            status_kind: :info
          }
        )
      end
      format.html { redirect_to functional_groups_path, notice: "Discovering functional groups across molecules with LLM..." }
    end
  end

  private

  def find_embeddable_record
    FunctionalGroup.find(params[:id])
  end
end
