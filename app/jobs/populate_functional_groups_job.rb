# frozen_string_literal: true

class PopulateFunctionalGroupsJob < ApplicationJob
  STREAM_NAME = "functional_groups"
  GLOBAL_STREAM_NAME = STREAM_NAME

  queue_as :default
  sidekiq_options retry: 0

  def perform(molecule_id: nil)
    Llm::ModelRegistry.ensure_configured_model!

    molecules = if molecule_id.present?
                  Molecule.where(id: molecule_id).includes(:chemical_class).to_a
    else
                  Molecule.includes(:chemical_class).joins(:chemical_class).order("chemical_classes.name ASC, molecules.name ASC").to_a
    end

    if molecules.empty?
      msg = molecule_id.present? ? "Molecule with ID #{molecule_id} not found." : "No molecules found. Populate molecules first before discovering functional groups."
      track_failed(error: msg, message: msg)
      broadcast_state(
        status_message: msg,
        status_kind: :error,
        running: false
      )
      return { total_upserted: 0, failed_molecules: [] }
    end

    total_upserted, failed_molecules = populate_across_molecules(molecules)
    summary = build_summary(total_upserted: total_upserted, total_molecules: molecules.size, failed_molecules: failed_molecules)

    if failed_molecules.size == molecules.size
      track_failed(error: summary[:message], message: summary[:message])
    else
      track_completed(
        message: summary[:message],
        result: { total_upserted: total_upserted, total_functional_groups: FunctionalGroup.count, failed_molecules: failed_molecules }
      )
    end

    broadcast_state(
      status_message: summary[:message],
      status_kind: summary[:kind],
      running: false
    )

    { total_upserted: total_upserted, failed_molecules: failed_molecules }
  rescue StandardError => e
    Rails.logger.error("[PopulateFunctionalGroupsJob] #{e.class}: #{e.message}")
    track_failed(error: e, message: "Failed to populate functional groups: #{e.message}")
    broadcast_state(
      status_message: "Failed to populate functional groups: #{e.message}",
      status_kind: :error,
      running: false
    )
    raise e if Rails.env.test? && !called_via_perform_later?
  end

  def populate_molecule!(molecule)
    existing_names = molecule.functional_groups.ordered.pluck(:name)
    chat = FunctionalGroupDiscoveryAgent.create!(
      molecule_name: molecule.name,
      molecule_description: molecule.description,
      molecule_themes: molecule.themes,
      chemical_class_name: molecule.chemical_class.name,
      existing_names: existing_names
    )
    response = chat.ask(discovery_prompt_for(molecule))

    entries = Llm::JsonResponseParser.extract_list(response, key: "functional_groups")
    upserted = FunctionalGroup.upsert_batch!(molecule, entries)
    raise "LLM response did not contain any valid functional groups for #{molecule.name}." if upserted.empty?

    upserted.size
  end

  private

  def called_via_perform_later?
    job_id.present?
  end

  def populate_across_molecules(molecules)
    total_upserted = 0
    failed_molecules = []

    molecules.each_with_index do |molecule, index|
      msg = "Discovering functional groups for #{molecule.name} (#{index + 1}/#{molecules.size})..."
      track_progress(message: msg, progress: { current: index + 1, total: molecules.size, molecule: molecule.name })
      broadcast_state(
        status_message: msg,
        status_kind: :info,
        running: true
      )

      total_upserted += populate_molecule!(molecule)
    rescue StandardError => e
      Rails.logger.error("[PopulateFunctionalGroupsJob] Molecule=#{molecule.name} #{e.class}: #{e.message}")
      failed_molecules << molecule.name
    end

    [ total_upserted, failed_molecules ]
  end

  def discovery_prompt_for(molecule)
    "Identify 6 to 10 major, chemically prominent functional groups, structural motifs, or atomic environments in #{molecule.name} (#{molecule.chemical_class.name}) and return them as a JSON list with name, description, and thematic tags."
  end

  def build_summary(total_upserted:, total_molecules:, failed_molecules:)
    total_functional_groups = FunctionalGroup.count
    if failed_molecules.empty?
      {
        kind: :success,
        message: "Upserted #{total_upserted} #{'functional group'.pluralize(total_upserted)} across #{total_molecules} #{'molecule'.pluralize(total_molecules)} (#{total_functional_groups} total)."
      }
    elsif failed_molecules.size == total_molecules
      {
        kind: :error,
        message: "Failed to populate functional groups for all molecules: #{failed_molecules.join(', ')}."
      }
    else
      {
        kind: :error,
        message: "Upserted #{total_upserted} #{'functional group'.pluralize(total_upserted)} (#{total_functional_groups} total). Failed molecules: #{failed_molecules.join(', ')}."
      }
    end
  end

  def broadcast_state(status_message:, status_kind:, running:)
    molecule_groups = FunctionalGroup.grouped_by_molecule
    total_functional_groups_count = FunctionalGroup.count
    molecules_count = Molecule.count

    Turbo::StreamsChannel.broadcast_replace_to(
      STREAM_NAME,
      target: "populate_all_functional_groups_controls",
      partial: "pages/populate_controls",
      locals: {
        target_id: "populate_all_functional_groups_controls",
        action_path: Rails.application.routes.url_helpers.populate_functional_groups_path,
        idle_label: "Discover Atoms / Functional Groups",
        running_label: "Discovering Atoms / Functional Groups...",
        running: running,
        status_message: status_message,
        status_kind: status_kind
      }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      STREAM_NAME,
      target: "functional_groups_list",
      partial: "pages/functional_groups_list",
      locals: {
        grouped_functional_groups: molecule_groups,
        molecule_groups: molecule_groups,
        total_functional_groups_count: total_functional_groups_count,
        molecules_count: molecules_count
      }
    )
  end
end
