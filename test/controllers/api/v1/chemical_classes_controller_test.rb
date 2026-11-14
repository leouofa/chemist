# frozen_string_literal: true

require "test_helper"

class Api::V1::ChemicalClassesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @chemical_class = ChemicalClass.create!(name: "Alkaloids", description: "Naturally occurring basic nitrogen compounds.")
  end

  test "GET /api/v1/chemical_classes returns list" do
    get api_v1_chemical_classes_url, as: :json
    assert_response :success

    json = response.parsed_body
    assert json["data"].is_a?(Array)
    assert json["meta"].key?("total")
    names = json["data"].map { |p| p["name"] }
    assert_includes names, "Alkaloids"
  end

  test "GET /api/v1/chemical_classes/:id returns single chemical_class" do
    get api_v1_chemical_class_url(@chemical_class), as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal @chemical_class.name, json.dig("data", "name")
  end

  test "POST /api/v1/chemical_classes creates a new chemical_class" do
    assert_difference("ChemicalClass.count", 1) do
      post api_v1_chemical_classes_url, params: { chemical_class: { name: "Terpenoids", description: "Diverse class of organic compounds derived from isoprene." } }, as: :json
    end
    assert_response :created

    json = response.parsed_body
    assert_equal "Terpenoids", json.dig("data", "name")
  end

  test "PATCH /api/v1/chemical_classes/:id updates a chemical_class" do
    patch api_v1_chemical_class_url(@chemical_class), params: { chemical_class: { description: "Updated description" } }, as: :json
    assert_response :success

    @chemical_class.reload
    assert_equal "Updated description", @chemical_class.description
  end

  test "DELETE /api/v1/chemical_classes/:id removes a chemical_class" do
    assert_difference("ChemicalClass.count", -1) do
      delete api_v1_chemical_class_url(@chemical_class), as: :json
    end
    assert_response :success
    assert response.parsed_body.dig("data", "deleted")
  end

  test "POST /api/v1/chemical_classes/upsert_batch upserts multiple chemical_classes" do
    payload = {
      chemical_classes: [
        { name: "Alkaloids", description: "New Alkaloids description" },
        { name: "Flavonoids", description: "Flavonoidsn chemical_class." }
      ]
    }

    assert_difference("ChemicalClass.count", 1) do
      post upsert_batch_api_v1_chemical_classes_url, params: payload, as: :json
    end
    assert_response :success

    assert_equal "New Alkaloids description", @chemical_class.reload.description
    assert ChemicalClass.find_by(name: "Flavonoids")
  end

  test "POST /api/v1/chemical_classes/populate enqueues PopulateChemicalClassesJob by default" do
    assert_enqueued_with(job: PopulateChemicalClassesJob) do
      post populate_api_v1_chemical_classes_url, as: :json
    end
    assert_response :accepted
    assert response.parsed_body.dig("data", "job_id").present?
  end

  test "POST /api/v1/chemical_classes/:id/populate_molecules enqueues PopulateMoleculesJob" do
    assert_enqueued_with(job: PopulateMoleculesJob, args: [ { chemical_class_id: @chemical_class.id } ]) do
      post populate_molecules_api_v1_chemical_class_url(@chemical_class), as: :json
    end
    assert_response :accepted
  end
end
