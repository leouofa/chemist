# frozen_string_literal: true

class PopulateMoleculesJob < ApplicationJob
  STREAM_NAME = "molecules"
  GLOBAL_STREAM_NAME = STREAM_NAME

  queue_as :default
  sidekiq_options retry: 0

  def perform(chemical_class_id: nil)
    Llm::ModelRegistry.ensure_configured_model!

    chemical_classes = if chemical_class_id.present?
                         ChemicalClass.where(id: chemical_class_id).to_a
    else
                         ChemicalClass.ordered.to_a
    end

    if chemical_classes.empty?
      msg = chemical_class_id.present? ? "Chemical class with ID #{chemical_class_id} not found." : "No chemical classes found. Populate chemical classes first before discovering molecules."
      track_failed(error: msg, message: msg)
      broadcast_state(
        status_message: msg,
        status_kind: :error,
        running: false
      )
      return { total_upserted: 0, failed_classes: [] }
    end

    total_upserted, failed_classes = populate_across_classes(chemical_classes)
    summary = build_summary(total_upserted: total_upserted, total_classes: chemical_classes.size, failed_classes: failed_classes)

    if failed_classes.size == chemical_classes.size
      track_failed(error: summary[:message], message: summary[:message])
    else
      track_completed(
        message: summary[:message],
        result: { total_upserted: total_upserted, total_molecules: Molecule.count, failed_classes: failed_classes }
      )
    end

    broadcast_state(
      status_message: summary[:message],
      status_kind: summary[:kind],
      running: false
    )

    { total_upserted: total_upserted, failed_classes: failed_classes }
  rescue StandardError => e
    Rails.logger.error("[PopulateMoleculesJob] #{e.class}: #{e.message}")
    track_failed(error: e, message: "Failed to populate molecules: #{e.message}")
    broadcast_state(
      status_message: "Failed to populate molecules: #{e.message}",
      status_kind: :error,
      running: false
    )
    raise e if Rails.env.test? && !called_via_perform_later?
  end

  def populate_chemical_class!(chemical_class)
    existing_names = chemical_class.molecules.ordered.pluck(:name)
    chat = MoleculeDiscoveryAgent.create!(
      chemical_class_name: chemical_class.name,
      chemical_class_description: chemical_class.description,
      existing_names: existing_names
    )
    response = chat.ask(discovery_prompt_for(chemical_class))

    entries = Llm::JsonResponseParser.extract_list(response, key: "molecules")
    upserted = Molecule.upsert_batch!(chemical_class, entries)
    raise "LLM response did not contain any valid molecules for #{chemical_class.name}." if upserted.empty?

    upserted.size
  end

  private

  def called_via_perform_later?
    job_id.present?
  end

  def populate_across_classes(chemical_classes)
    total_upserted = 0
    failed_classes = []

    chemical_classes.each_with_index do |chem_class, index|
      msg = "Discovering molecules for #{chem_class.name} (#{index + 1}/#{chemical_classes.size})..."
      track_progress(message: msg, progress: { current: index + 1, total: chemical_classes.size, chemical_class: chem_class.name })
      broadcast_state(
        status_message: msg,
        status_kind: :info,
        running: true
      )

      total_upserted += populate_chemical_class!(chem_class)
    rescue StandardError => e
      Rails.logger.error("[PopulateMoleculesJob] ChemicalClass=#{chem_class.name} #{e.class}: #{e.message}")
      failed_classes << chem_class.name
    end

    [ total_upserted, failed_classes ]
  end

  def discovery_prompt_for(chemical_class)
    "Find prominent, archetypal molecules and compounds belonging to #{chemical_class.name} and return their names, descriptions, and thematic tags as JSON."
  end

  def build_summary(total_upserted:, total_classes:, failed_classes:)
    total_molecules = Molecule.count
    if failed_classes.empty?
      {
        kind: :success,
        message: "Upserted #{total_upserted} #{'molecule'.pluralize(total_upserted)} across #{total_classes} #{'chemical class'.pluralize(total_classes)} (#{total_molecules} total)."
      }
    elsif failed_classes.size == total_classes
      {
        kind: :error,
        message: "Failed to populate molecules for all chemical classes: #{failed_classes.join(', ')}."
      }
    else
      {
        kind: :error,
        message: "Upserted #{total_upserted} #{'molecule'.pluralize(total_upserted)} (#{total_molecules} total). Failed chemical classes: #{failed_classes.join(', ')}."
      }
    end
  end

  def broadcast_state(status_message:, status_kind:, running:)
    chemical_class_groups = Molecule.grouped_by_chemical_class
    total_molecules_count = Molecule.count
    chemical_classes_count = ChemicalClass.count

    Turbo::StreamsChannel.broadcast_replace_to(
      STREAM_NAME,
      target: "populate_all_molecules_controls",
      partial: "pages/populate_controls",
      locals: {
        target_id: "populate_all_molecules_controls",
        action_path: Rails.application.routes.url_helpers.populate_molecules_path,
        idle_label: "Discover Molecules",
        running_label: "Discovering Molecules...",
        running: running,
        status_message: status_message,
        status_kind: status_kind
      }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      STREAM_NAME,
      target: "molecules_list",
      partial: "pages/molecules_list",
      locals: {
        grouped_molecules: chemical_class_groups,
        chemical_class_groups: chemical_class_groups,
        total_molecules_count: total_molecules_count,
        chemical_classes_count: chemical_classes_count
      }
    )
  end
end
