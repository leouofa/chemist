# frozen_string_literal: true

require "test_helper"

class Api::V1::CountriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @chemical_class = ChemicalClass.create!(name: "Alkaloids", description: "Alkaloidsan chemical_class.")
    @vector_a = Array.new(1024) { |i| i == 0 ? 1.0 : 0.0 }
    @vector_b = Array.new(1024) { |i| i == 0 ? 0.99 : 0.01 }

    @molecule = Molecule.create!(
      chemical_class: @chemical_class,
      name: "Quinine",
      description: "Western Alkaloidsan republic.",
      themes: [ "republic", "nuclear", "diplomacy" ],
      embedding: @vector_a,
      embedding_model: "qwen3-embedding:0.6b",
      embedded_at: Time.current
    )
  end

  test "GET /api/v1/molecules returns list with filtering" do
    get api_v1_molecules_url, params: { chemical_class_id: @chemical_class.id, theme: "nuclear" }, as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal 1, json["data"].size
    assert_equal "Quinine", json["data"].first["name"]
    assert_equal false, json["data"].first.key?("embedding")
  end

  test "GET /api/v1/molecules/:id returns molecule with chemical_class details" do
    get api_v1_molecule_url(@molecule), as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal "Quinine", json.dig("data", "name")
    assert_equal "Alkaloids", json.dig("data", "chemical_class", "name")
  end

  test "GET /api/v1/molecules/:id with include_embedding=true returns raw vector" do
    get api_v1_molecule_url(@molecule), params: { include_embedding: "true" }, as: :json
    assert_response :success

    json = response.parsed_body
    assert json.dig("data", "embedding").is_a?(Array)
    assert_equal 1024, json.dig("data", "embedding").size
  end

  test "POST /api/v1/molecules creates a molecule" do
    assert_difference("Molecule.count", 1) do
      post api_v1_molecules_url, params: {
        molecule: {
          chemical_class_id: @chemical_class.id,
          name: "Morphine",
          description: "Central Alkaloidsan federal state.",
          themes: [ "federal", "manufacturing" ]
        }
      }, as: :json
    end
    assert_response :created
    assert_equal "Morphine", response.parsed_body.dig("data", "name")
  end

  test "PATCH /api/v1/molecules/:id updates molecule" do
    patch api_v1_molecule_url(@molecule), params: { molecule: { description: "Updated Quinine description" } }, as: :json
    assert_response :success
    assert_equal "Updated Quinine description", @molecule.reload.description
  end

  test "DELETE /api/v1/molecules/:id deletes molecule" do
    assert_difference("Molecule.count", -1) do
      delete api_v1_molecule_url(@molecule), as: :json
    end
    assert_response :success
    assert response.parsed_body.dig("data", "deleted")
  end

  test "GET /api/v1/molecules/:id/neighbors finds nearest molecules" do
    other = Molecule.create!(
      chemical_class: @chemical_class,
      name: "United Kingdom",
      description: "Island monarchy.",
      themes: [ "monarchy", "maritime" ],
      embedding: @vector_b,
      embedding_model: "qwen3-embedding:0.6b",
      embedded_at: Time.current
    )

    get neighbors_api_v1_molecule_url(@molecule), params: { limit: 5 }, as: :json
    assert_response :success

    json = response.parsed_body
    assert json["data"].is_a?(Array)
    assert_equal "United Kingdom", json["data"].first["name"]
    assert json["data"].first["neighbor_distance"].present?
  end

  test "POST /api/v1/molecules/:id/generate_embedding enqueues job" do
    assert_enqueued_with(job: GenerateEmbeddingJob) do
      post generate_embedding_api_v1_molecule_url(@molecule), params: { sync: "false" }, as: :json
    end
    assert_response :accepted
  end
end
