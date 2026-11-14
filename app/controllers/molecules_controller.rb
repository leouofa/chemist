# frozen_string_literal: true

class MoleculesController < ApplicationController
  include EmbeddableActions

  def show
    @molecule = Molecule.includes(:chemical_class, :functional_groups).find(params[:id])

    respond_to do |format|
      format.html
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(
          "cluster_modal",
          partial: "molecules/modal",
          locals: { molecule: @molecule }
        )
      end
    end
  end

  def generate_embedding
    @molecule = Molecule.find(params[:id])
    enqueue_embedding_generation(@molecule)
  end

  def populate
    PopulateMoleculesJob.perform_later

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "populate_all_molecules_controls",
          partial: "pages/populate_controls",
          locals: {
            target_id: "populate_all_molecules_controls",
            action_path: populate_molecules_path,
            idle_label: "Discover Molecules",
            running_label: "Discovering Molecules...",
            running: true,
            status_message: "Discovering molecules across chemical classes with LLM...",
            status_kind: :info
          }
        )
      end
      format.html { redirect_to molecules_path, notice: "Discovering molecules across chemical classes with LLM..." }
    end
  end

  def populate_functional_groups
    @molecule = Molecule.find(params[:id])
    PopulateFunctionalGroupsJob.perform_later(molecule_id: @molecule.id)

    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = "Discovering functional groups for #{@molecule.name}..."
        render turbo_stream: turbo_stream.replace(
          "molecule_functional_groups_section",
          partial: "molecules/functional_groups_section",
          locals: { molecule: @molecule, status_message: flash.now[:notice], status_kind: :info }
        )
      end
      format.html { redirect_to molecule_path(@molecule), notice: "Discovering functional groups for #{@molecule.name}..." }
    end
  end

  private

  def find_embeddable_record
    Molecule.find(params[:id])
  end
end
