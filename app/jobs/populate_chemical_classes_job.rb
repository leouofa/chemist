# frozen_string_literal: true

class PopulateChemicalClassesJob < ApplicationJob
  queue_as :default

  STREAM_NAME = "populate_chemical_classes"
  DISCOVERY_PROMPT = "Identify major chemical classes across organic, biochemical/medicinal, inorganic, organometallic, and materials chemistry (e.g. Alkaloids, Carboxylic Acids & Esters, Aromatic Hydrocarbons, Amino Acids & Peptides, Terpenoids & Steroids, Transition Metal Coordination Complexes, Organophosphorus Compounds, Beta-Lactam Antibiotics, Crown Ethers & Macrocycles, Conductive Polymers) and return their canonical names and descriptions as JSON."

  def perform
    Llm::ModelRegistry.ensure_configured_model!

    existing_names = ChemicalClass.ordered.pluck(:name)
    chat = ChemicalClassDiscoveryAgent.create!(existing_names: existing_names)
    response = chat.ask(DISCOVERY_PROMPT)

    entries = Llm::JsonResponseParser.extract_list(response, key: "chemical_classes")
    upserted = ChemicalClass.upsert_batch!(entries)
    raise "LLM response did not contain any valid chemical classes." if upserted.empty?

    message = "Upserted #{upserted.size} #{'chemical class'.pluralize(upserted.size)} (#{ChemicalClass.count} total)."
    track_completed(message: message, result: { upserted_count: upserted.size, total_count: ChemicalClass.count })

    broadcast_state(
      status_message: message,
      status_kind: :success,
      running: false
    )
    { upserted_count: upserted.size, total_count: ChemicalClass.count }
  rescue StandardError => e
    Rails.logger.error("[PopulateChemicalClassesJob] #{e.class}: #{e.message}")
    track_failed(error: e, message: "Failed to populate chemical classes: #{e.message}")
    broadcast_state(
      status_message: "Failed to populate chemical classes: #{e.message}",
      status_kind: :error,
      running: false
    )
    raise e if Rails.env.test? && !called_via_perform_later?
  end

  private

  def called_via_perform_later?
    job_id.present?
  end

  def broadcast_state(status_message:, status_kind:, running:)
    chemical_classes = ChemicalClass.ordered.to_a

    Turbo::StreamsChannel.broadcast_replace_to(
      STREAM_NAME,
      target: "populate_controls",
      partial: "pages/populate_controls",
      locals: {
        target_id: "populate_controls",
        action_path: Rails.application.routes.url_helpers.populate_chemical_classes_path,
        idle_label: "Populate Chemical Classes",
        running_label: "Discovering Chemical Classes...",
        running: running,
        status_message: status_message,
        status_kind: status_kind
      }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      STREAM_NAME,
      target: "chemical_classes_list",
      partial: "pages/chemical_classes_list",
      locals: { chemical_classes: chemical_classes }
    )
  end
end
