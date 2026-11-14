# frozen_string_literal: true

require "test_helper"

class GenerateAllEmbeddingsJobTest < ActiveJob::TestCase
  include ActionCable::TestHelper

  test "perform with only_missing: true skips already-embedded molecules and embeds missing ones" do
    europe = ChemicalClass.create!(name: "Alkaloids", description: "Naturally occurring basic nitrogen compounds.")
    existing_vector = Array.new(1024, 0.1)
    quinine = Molecule.create!(
      chemical_class: europe,
      name: "Quinine",
      description: "Natural antimalarial alkaloid.",
      embedding: existing_vector,
      embedding_model: "old-model",
      embedded_at: 1.day.ago
    )
    morphine = Molecule.create!(chemical_class: europe, name: "Morphine", description: "Opioid analgesic alkaloid.")

    new_vector = Array.new(1024, 0.2)
    called_texts = []

    with_stubbed_generator(->(text) {
      called_texts << text
      { vector: new_vector, model: "qwen3-embedding:0.6b" }
    }) do
      assert_broadcasts(GenerateAllEmbeddingsJob::STREAM_NAME, 2) do
        GenerateAllEmbeddingsJob.perform_now("Molecule", only_missing: true)
      end
    end

    assert_equal 1, called_texts.size
    assert_match "Morphine", called_texts.first
    assert_equal "old-model", quinine.reload.embedding_model
    assert_equal "qwen3-embedding:0.6b", morphine.reload.embedding_model
  end

  test "perform with only_missing: false regenerates all functional_groups" do
    europe = ChemicalClass.create!(name: "Alkaloids", description: "Naturally occurring basic nitrogen compounds.")
    quinine = Molecule.create!(chemical_class: europe, name: "Quinine", description: "Natural antimalarial alkaloid.")
    morphine = Molecule.create!(chemical_class: europe, name: "Morphine", description: "Opioid analgesic alkaloid.")

    functional_group1 = FunctionalGroup.create!(
      molecule: quinine,
      name: "Quinoline Ring",
      description: "Aromatic nitrogen heterocycle.",
      themes: [ "heterocycle" ],
      embedding: Array.new(1024, 0.1),
      embedding_model: "old-model",
      embedded_at: 1.day.ago
    )
    functional_group2 = FunctionalGroup.create!(molecule: morphine, name: "Phenanthrene Core", description: "Fused ring core.", themes: [ "core" ])

    new_vector = Array.new(1024, 0.3)
    called_count = 0

    with_stubbed_generator(->(_text) {
      called_count += 1
      { vector: new_vector, model: "qwen3-embedding:0.6b" }
    }) do
      assert_broadcasts(GenerateAllEmbeddingsJob::STREAM_NAME, 3) do
        GenerateAllEmbeddingsJob.perform_now("FunctionalGroup", only_missing: false)
      end
    end

    assert_equal 2, called_count
    assert_equal "qwen3-embedding:0.6b", functional_group1.reload.embedding_model
    assert_equal "qwen3-embedding:0.6b", functional_group2.reload.embedding_model
  end

  test "perform continues remaining records when one record fails" do
    europe = ChemicalClass.create!(name: "Alkaloids", description: "Naturally occurring basic nitrogen compounds.")
    quinine = Molecule.create!(chemical_class: europe, name: "Quinine", description: "Natural antimalarial alkaloid.")
    morphine = Molecule.create!(chemical_class: europe, name: "Morphine", description: "Opioid analgesic alkaloid.")

    new_vector = Array.new(1024, 0.4)

    with_stubbed_generator(->(text) {
      raise "Temporary timeout" if text.include?("Quinine")

      { vector: new_vector, model: "qwen3-embedding:0.6b" }
    }) do
      assert_broadcasts(GenerateAllEmbeddingsJob::STREAM_NAME, 3) do
        GenerateAllEmbeddingsJob.perform_now("Molecule", only_missing: true)
      end
    end

    assert_not quinine.reload.embedded?
    assert morphine.reload.embedded?
  end

  test "perform broadcasts info message when nothing needs embedding" do
    assert_broadcasts(GenerateAllEmbeddingsJob::STREAM_NAME, 1) do
      GenerateAllEmbeddingsJob.perform_now("Molecule", only_missing: true)
    end
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
