# frozen_string_literal: true

require "test_helper"

class MoleculesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "populate enqueues PopulateMoleculesJob and responds with turbo stream" do
    assert_enqueued_with(job: PopulateMoleculesJob) do
      post populate_molecules_url, as: :turbo_stream
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_match "Discovering Molecules...", response.body
  end

  test "populate enqueues PopulateMoleculesJob and redirects for HTML requests" do
    assert_enqueued_with(job: PopulateMoleculesJob) do
      post populate_molecules_url
    end

    assert_redirected_to molecules_url
  end

  test "show renders molecule details and Generate Embedding button" do
    europe = ChemicalClass.create!(name: "Alkaloids", description: "Naturally occurring basic nitrogen compounds.")
    molecule = Molecule.create!(chemical_class: europe, name: "Quinine", description: "Natural antimalarial alkaloid.", themes: [ "alkaloid" ])

    get molecule_url(molecule)

    assert_response :success
    assert_match "Quinine", response.body
    assert_match "Generate Embedding", response.body
    assert_match "Not generated", response.body
  end

  test "show with Turbo-Frame cluster_modal renders modal partial" do
    europe = ChemicalClass.create!(name: "Alkaloids", description: "Naturally occurring basic nitrogen compounds.")
    molecule = Molecule.create!(chemical_class: europe, name: "Quinine", description: "Natural antimalarial alkaloid.", themes: [ "alkaloid" ])

    get molecule_url(molecule), headers: { "Turbo-Frame" => "cluster_modal" }

    assert_response :success
    assert_select "turbo-frame#cluster_modal"
    assert_match "Quinine", response.body
    assert_match "Back to Clusters", response.body
    assert_match "Open Full Molecule Page", response.body
  end

  test "generate_embedding enqueues GenerateEmbeddingJob and responds with turbo stream" do
    europe = ChemicalClass.create!(name: "Alkaloids", description: "Naturally occurring basic nitrogen compounds.")
    molecule = Molecule.create!(chemical_class: europe, name: "Quinine", description: "Natural antimalarial alkaloid.")

    assert_enqueued_with(job: GenerateEmbeddingJob, args: [ "Molecule", molecule.id ]) do
      post generate_embedding_molecule_url(molecule), as: :turbo_stream
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_match "Generating Embedding...", response.body
  end

  test "generate_embedding enqueues GenerateEmbeddingJob and redirects for HTML requests" do
    europe = ChemicalClass.create!(name: "Alkaloids", description: "Naturally occurring basic nitrogen compounds.")
    molecule = Molecule.create!(chemical_class: europe, name: "Quinine", description: "Natural antimalarial alkaloid.")

    assert_enqueued_with(job: GenerateEmbeddingJob, args: [ "Molecule", molecule.id ]) do
      post generate_embedding_molecule_url(molecule)
    end

    assert_redirected_to molecule_url(molecule)
  end
end
