# frozen_string_literal: true

require "test_helper"

class FunctionalGroupsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "populate enqueues PopulateFunctionalGroupsJob and responds with turbo stream" do
    assert_enqueued_with(job: PopulateFunctionalGroupsJob) do
      post populate_functional_groups_url, as: :turbo_stream
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_match "Discovering Atoms / Functional Groups...", response.body
  end

  test "populate enqueues PopulateFunctionalGroupsJob and redirects for HTML requests" do
    assert_enqueued_with(job: PopulateFunctionalGroupsJob) do
      post populate_functional_groups_url
    end

    assert_redirected_to functional_groups_url
  end

  test "show renders functional_group details and Generate Embedding button" do
    europe = ChemicalClass.create!(name: "Alkaloids", description: "Alkaloidsan chemical_class.")
    molecule = Molecule.create!(chemical_class: europe, name: "Quinine", description: "Western Alkaloidsan republic.")
    functional_group = FunctionalGroup.create!(molecule: molecule, name: "Quinoline Ring", description: "National capital.", themes: [ "capital" ])

    get functional_group_url(functional_group)

    assert_response :success
    assert_match "Quinoline Ring", response.body
    assert_match "Quinine", response.body
    assert_match "Generate Embedding", response.body
    assert_match "Not generated", response.body
  end

  test "show with Turbo-Frame cluster_modal renders modal partial" do
    europe = ChemicalClass.create!(name: "Alkaloids", description: "Alkaloidsan chemical_class.")
    molecule = Molecule.create!(chemical_class: europe, name: "Quinine", description: "Western Alkaloidsan republic.")
    functional_group = FunctionalGroup.create!(molecule: molecule, name: "Quinoline Ring", description: "National capital.", themes: [ "capital" ])

    get functional_group_url(functional_group), headers: { "Turbo-Frame" => "cluster_modal" }

    assert_response :success
    assert_select "turbo-frame#cluster_modal"
    assert_match "Quinoline Ring", response.body
    assert_match "Back to Clusters", response.body
    assert_match "Open Full Functional Group / Atomic Site Page", response.body
  end

  test "generate_embedding enqueues GenerateEmbeddingJob and responds with turbo stream" do
    europe = ChemicalClass.create!(name: "Alkaloids", description: "Alkaloidsan chemical_class.")
    molecule = Molecule.create!(chemical_class: europe, name: "Quinine", description: "Western Alkaloidsan republic.")
    functional_group = FunctionalGroup.create!(molecule: molecule, name: "Quinoline Ring", description: "National capital.", themes: [ "capital" ])

    assert_enqueued_with(job: GenerateEmbeddingJob, args: [ "FunctionalGroup", functional_group.id ]) do
      post generate_embedding_functional_group_url(functional_group), as: :turbo_stream
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_match "Generating Embedding...", response.body
  end

  test "generate_embedding enqueues GenerateEmbeddingJob and redirects for HTML requests" do
    europe = ChemicalClass.create!(name: "Alkaloids", description: "Alkaloidsan chemical_class.")
    molecule = Molecule.create!(chemical_class: europe, name: "Quinine", description: "Western Alkaloidsan republic.")
    functional_group = FunctionalGroup.create!(molecule: molecule, name: "Quinoline Ring", description: "National capital.", themes: [ "capital" ])

    assert_enqueued_with(job: GenerateEmbeddingJob, args: [ "FunctionalGroup", functional_group.id ]) do
      post generate_embedding_functional_group_url(functional_group)
    end

    assert_redirected_to functional_group_url(functional_group)
  end
end
