# frozen_string_literal: true

require "test_helper"

class Api::V1::FunctionalGroupsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @chemical_class = ChemicalClass.create!(name: "Alkaloids", description: "Alkaloid chemical class.")
    @vector_a = Array.new(1024) { |i| i == 0 ? 1.0 : 0.0 }
    @vector_b = Array.new(1024) { |i| i == 0 ? 0.98 : 0.02 }

    @molecule = Molecule.create!(chemical_class: @chemical_class, name: "Quinine", description: "Natural antimalarial alkaloid.", themes: [ "alkaloid" ])
    @other_molecule = Molecule.create!(chemical_class: @chemical_class, name: "Morphine", description: "Opioid analgesic alkaloid.", themes: [ "analgesic" ])

    @functional_group = FunctionalGroup.create!(
      molecule: @molecule,
      name: "Quinoline Ring",
      description: "Bicyclic aromatic nitrogen heterocycle.",
      themes: [ "heterocycle", "aromatic" ],
      embedding: @vector_a,
      embedding_model: "qwen3-embedding:0.6b",
      embedded_at: Time.current
    )
  end

  test "GET /api/v1/functional_groups returns list" do
    get api_v1_functional_groups_url, as: :json
    assert_response :success

    json = response.parsed_body
    assert json["data"].is_a?(Array)
    assert_equal 1, json["data"].size
    assert_equal "Quinoline Ring", json["data"].first["name"]
    assert_equal "Quinine", json["data"].first.dig("molecule", "name")
  end

  test "GET /api/v1/functional_groups/:id returns functional_group" do
    get api_v1_functional_group_url(@functional_group), as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal @functional_group.id, json.dig("data", "id")
    assert_equal "Quinoline Ring", json.dig("data", "name")
    assert_includes json.dig("data", "themes"), "heterocycle"
  end

  test "POST /api/v1/functional_groups creates functional_group for a molecule" do
    assert_difference("FunctionalGroup.count", 1) do
      post api_v1_functional_groups_url, params: {
        functional_group: {
          molecule_id: @other_molecule.id,
          name: "Phenanthrene Core",
          description: "Polycyclic aromatic hydrocarbon scaffold.",
          themes: [ "polycyclic", "core" ]
        }
      }, as: :json
    end
    assert_response :created
    assert_equal "Phenanthrene Core", response.parsed_body.dig("data", "name")
    assert_equal @other_molecule.id, response.parsed_body.dig("data", "molecule_id")
  end

  test "PATCH /api/v1/functional_groups/:id updates functional_group" do
    patch api_v1_functional_group_url(@functional_group), params: {
      functional_group: {
        description: "Updated Quinoline Ring description."
      }
    }, as: :json
    assert_response :success
    assert_equal "Updated Quinoline Ring description.", @functional_group.reload.description
  end

  test "DELETE /api/v1/functional_groups/:id deletes functional_group" do
    assert_difference("FunctionalGroup.count", -1) do
      delete api_v1_functional_group_url(@functional_group), as: :json
    end
    assert_response :success
    assert response.parsed_body.dig("data", "deleted")
  end

  test "GET /api/v1/functional_groups/:id/neighbors finds nearest functional_groups" do
    other_functional_group = FunctionalGroup.create!(
      molecule: @molecule,
      name: "Quinuclidine Nitrogen",
      description: "Bicyclic tertiary amine functional group.",
      themes: [ "amine", "tertiary" ],
      embedding: @vector_b,
      embedding_model: "qwen3-embedding:0.6b",
      embedded_at: Time.current
    )

    get neighbors_api_v1_functional_group_url(@functional_group), params: { limit: 5 }, as: :json
    assert_response :success

    json = response.parsed_body
    assert json["data"].is_a?(Array)
    assert_equal other_functional_group.id, json["data"].first["id"]
    assert json["data"].first["neighbor_distance"].present?
  end

  test "POST /api/v1/functional_groups/:id/generate_embedding enqueues job" do
    assert_enqueued_with(job: GenerateEmbeddingJob) do
      post generate_embedding_api_v1_functional_group_url(@functional_group), params: { sync: "false" }, as: :json
    end
    assert_response :accepted
  end
end
