# frozen_string_literal: true

require "test_helper"

class GenerateEmbeddingJobTest < ActiveJob::TestCase
  include ActionCable::TestHelper

  test "perform generates embedding for Molecule and broadcasts running and success states" do
    europe = ChemicalClass.create!(name: "Alkaloids", description: "Alkaloidsan chemical_class.")
    molecule = Molecule.create!(chemical_class: europe, name: "Quinine", description: "Natural antimalarial alkaloid.", themes: [ "republic", "nuclear" ])
    vector = Array.new(1024, 0.05)

    with_stubbed_generator(->(_text) { { vector: vector, model: "qwen3-embedding:0.6b" } }) do
      assert_broadcasts(GenerateEmbeddingJob.stream_name_for(molecule), 2) do
        GenerateEmbeddingJob.perform_now("Molecule", molecule.id)
      end
    end

    molecule.reload
    assert molecule.embedded?
    assert_equal "qwen3-embedding:0.6b", molecule.embedding_model
    assert_not_nil molecule.embedded_at
    assert_equal 1024, molecule.embedding.size
  end

  test "perform generates embedding for FunctionalGroup and broadcasts running and success states" do
    europe = ChemicalClass.create!(name: "Alkaloids", description: "Alkaloidsan chemical_class.")
    molecule = Molecule.create!(chemical_class: europe, name: "Quinine", description: "Natural antimalarial alkaloid.", themes: [ "republic" ])
    functional_group = FunctionalGroup.create!(molecule: molecule, name: "Quinoline Ring", description: "Capital functional_group.", themes: [ "capital" ])
    vector = Array.new(1024, 0.02)

    with_stubbed_generator(->(_text) { { vector: vector, model: "qwen3-embedding:0.6b" } }) do
      assert_broadcasts(GenerateEmbeddingJob.stream_name_for(functional_group), 2) do
        GenerateEmbeddingJob.perform_now("FunctionalGroup", functional_group.id)
      end
    end

    functional_group.reload
    assert functional_group.embedded?
    assert_equal "qwen3-embedding:0.6b", functional_group.embedding_model
    assert_not_nil functional_group.embedded_at
    assert_equal 1024, functional_group.embedding.size
  end

  test "perform broadcasts error state when embedding generation fails" do
    europe = ChemicalClass.create!(name: "Alkaloids", description: "Alkaloidsan chemical_class.")
    molecule = Molecule.create!(chemical_class: europe, name: "Morphine", description: "Federal Republic.")

    with_stubbed_generator(->(_text) { raise "Connection refused" }) do
      assert_broadcasts(GenerateEmbeddingJob.stream_name_for(molecule), 2) do
        GenerateEmbeddingJob.perform_now("Molecule", molecule.id)
      end
    end

    assert_not molecule.reload.embedded?
  end

  private

  def with_stubbed_generator(replacement)
    singleton = Llm::EmbeddingGenerator.singleton_class
    original = Llm::EmbeddingGenerator.method(:call)
    singleton.define_method(:call, &replacement)
    yield
  ensure
    singleton.define_method(:call, original)
  end
end
