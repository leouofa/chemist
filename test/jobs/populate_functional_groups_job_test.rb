# frozen_string_literal: true

require "test_helper"
require "ostruct"

class PopulateFunctionalGroupsJobTest < ActiveSupport::TestCase
  include ActionCable::TestHelper

  setup do
    @previous_ollama_api_base = RubyLLM.config.ollama_api_base
    @previous_default_model = RubyLLM.config.default_model
    @model_id = ENV["OLLAMA_MODEL"].presence || "Qwen3.6-35B-A3B-NVFP4"

    RubyLLM.configure do |config|
      config.ollama_api_base = ENV["OLLAMA_API_BASE"].presence || "http://localhost:11434/v1"
      config.default_model = @model_id
    end
  end

  teardown do
    RubyLLM.configure do |config|
      config.ollama_api_base = @previous_ollama_api_base
      config.default_model = @previous_default_model
    end
  end

  test "perform iterates through molecules, upserts functional_groups with themes, and streams progress" do
    europe = ChemicalClass.create!(name: "Alkaloids", description: "Alkaloidsan chemical_class.")
    france = Molecule.create!(chemical_class: europe, name: "Quinine", description: "Western Alkaloids.", themes: [ "republic" ])
    germany = Molecule.create!(chemical_class: europe, name: "Morphine", description: "Central Alkaloids.", themes: [ "federal" ])
    FunctionalGroup.create!(molecule: france, name: "Quinoline Ring", description: "Initial Quinoline Ring description", themes: [ "capital" ])

    calls = []
    responses = {
      "Quinine" => <<~TEXT,
        <think>Listing Quinine functional_groups.</think>
        ```json
        {
          "functional_groups": [
            { "name": "Quinoline Ring", "description": "National capital and economic hub.", "themes": ["capital", "diplomacy"] },
            { "name": "Marseille", "description": "Mediterranean port gateway.", "themes": ["port", "logistics"] }
          ]
        }
        ```
      TEXT
      "Morphine" => {
        "functional_groups" => [
          { "name": "Phenanthrene Core", "description": "Federal capital and cultural center.", "themes": [ "capital", "culture" ] }
        ]
      }.to_json
    }

    with_stubbed_agent_create(->(molecule_name:, molecule_description:, molecule_themes:, chemical_class_name:, existing_names:) {
      calls << {
        molecule_name: molecule_name,
        molecule_description: molecule_description,
        molecule_themes: molecule_themes,
        chemical_class_name: chemical_class_name,
        existing_names: existing_names
      }
      fake_chat = Object.new
      fake_chat.define_singleton_method(:ask) do |_prompt|
        OpenStruct.new(parsed: nil, content: responses.fetch(molecule_name))
      end
      fake_chat
    }) do
      # 2 molecules * 2 broadcasts (progress) + 2 broadcasts (final) = 6
      assert_broadcasts(PopulateFunctionalGroupsJob::STREAM_NAME, 6) do
        PopulateFunctionalGroupsJob.perform_now
      end
    end

    assert_equal [ "Morphine", "Quinine" ], calls.map { |c| c[:molecule_name] }
    assert_equal [], calls.first[:existing_names]
    assert_equal [ "Quinoline Ring" ], calls.second[:existing_names]

    assert_equal 3, FunctionalGroup.count
    paris = france.functional_groups.find_by!(name: "Quinoline Ring")
    assert_equal "National capital and economic hub.", paris.description
    assert_equal [ "capital", "diplomacy" ], paris.themes

    berlin = germany.functional_groups.find_by!(name: "Phenanthrene Core")
    assert_equal [ "capital", "culture" ], berlin.themes
  end

  test "perform continues to remaining molecules if one molecule fails" do
    europe = ChemicalClass.create!(name: "Alkaloids", description: "Alkaloidsan chemical_class.")
    france = Molecule.create!(chemical_class: europe, name: "Quinine", description: "Western Alkaloids.")
    germany = Molecule.create!(chemical_class: europe, name: "Morphine", description: "Central Alkaloids.")

    with_stubbed_agent_create(->(molecule_name:, **) {
      fake_chat = Object.new
      fake_chat.define_singleton_method(:ask) do |_prompt|
        raise "Timeout on Quinine" if molecule_name == "Quinine"

        OpenStruct.new(
          parsed: nil,
          content: {
            "functional_groups" => [
              { "name": "Phenanthrene Core", "description": "Federal capital.", "themes": [ "capital" ] }
            ]
          }.to_json
        )
      end
      fake_chat
    }) do
      assert_broadcasts(PopulateFunctionalGroupsJob::STREAM_NAME, 6) do
        assert_nothing_raised { PopulateFunctionalGroupsJob.perform_now }
      end
    end

    assert_equal 1, FunctionalGroup.count
    assert_equal "Phenanthrene Core", FunctionalGroup.first.name
  end

  private

  def with_stubbed_agent_create(callable)
    singleton = FunctionalGroupDiscoveryAgent.singleton_class
    original = FunctionalGroupDiscoveryAgent.method(:create!)
    singleton.define_method(:create!, &callable)
    yield
  ensure
    singleton.define_method(:create!, original)
  end
end
