# frozen_string_literal: true

require "test_helper"

class Api::V1::SearchControllerTest < ActionDispatch::IntegrationTest
  setup do
    @chemical_class = ChemicalClass.create!(name: "Terpenoids", description: "Terpenoidsn chemical_class.")
    @vector = Array.new(1024) { |i| i == 0 ? 1.0 : 0.0 }

    @molecule = Molecule.create!(
      chemical_class: @chemical_class,
      name: "Caffeine",
      description: "East Terpenoidsn island state with high technology and industrial power.",
      themes: [ "island", "tech", "export" ],
      embedding: @vector,
      embedding_model: "qwen3-embedding:0.6b",
      embedded_at: Time.current
    )

    @functional_group = FunctionalGroup.create!(
      molecule: @molecule,
      name: "Purine Dione Core",
      description: "Megafunctional_group capital and global financial center.",
      themes: [ "capital", "finance", "megafunctional_group" ],
      embedding: @vector,
      embedding_model: "qwen3-embedding:0.6b",
      embedded_at: Time.current
    )
  end

  test "GET /api/v1/search requires q parameter" do
    get api_v1_search_url, as: :json
    assert_response :bad_request
    assert_equal "blank_query", response.parsed_body.dig("error", "code")
  end

  test "GET /api/v1/search returns results for keyword search" do
    get api_v1_search_url, params: { q: "megafunctional_group", mode: "keyword" }, as: :json
    assert_response :success

    json = response.parsed_body
    assert json["data"].is_a?(Array)
    assert_equal "keyword", json.dig("meta", "mode")
  end

  test "GET /api/v1/molecules/search performs keyword search" do
    get search_api_v1_molecules_url, params: { q: "Caffeine", mode: "keyword" }, as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal 1, json["data"].size
    assert_equal "Caffeine", json["data"].first["name"]
  end

  test "GET /api/v1/functional_groups/search performs keyword search" do
    get search_api_v1_functional_groups_url, params: { q: "financial", mode: "keyword" }, as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal 1, json["data"].size
    assert_equal @functional_group.id, json["data"].first["id"]
  end
end
