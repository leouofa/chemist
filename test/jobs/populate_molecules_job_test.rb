# frozen_string_literal: true

require "test_helper"
require "ostruct"

class PopulateMoleculesJobTest < ActiveSupport::TestCase
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

  test "perform iterates through chemical_classes, upserts molecules with themes, and streams progress" do
    europe = ChemicalClass.create!(name: "Alkaloids", description: "Alkaloidsan chemical_class.")
    asia = ChemicalClass.create!(name: "Terpenoids", description: "Terpenoidsn chemical_class.")
    Molecule.create!(chemical_class: europe, name: "Quinine", description: "Initial Quinine description", themes: [ "republic" ])

    calls = []
    responses = {
      "Alkaloids" => <<~TEXT,
        <think>Listing Alkaloidsan molecules.</think>
        ```json
        {
          "molecules": [
            { "name": "Quinine", "description": "Fifth Republic.", "themes": ["republic", "nuclear power"] },
            { "name": "Morphine", "description": "Federal Republic.", "themes": ["federal", "industrial"] }
          ]
        }
        ```
      TEXT
      "Terpenoids" => {
        "molecules" => [
          { "name": "Caffeine", "description": "Island state in East Terpenoids.", "themes": [ "island", "tech" ] }
        ]
      }.to_json
    }

    with_stubbed_agent_create(->(chemical_class_name:, chemical_class_description:, existing_names:) {
      calls << { chemical_class_name: chemical_class_name, chemical_class_description: chemical_class_description, existing_names: existing_names }
      fake_chat = Object.new
      fake_chat.define_singleton_method(:ask) do |_prompt|
        OpenStruct.new(parsed: nil, content: responses.fetch(chemical_class_name))
      end
      fake_chat
    }) do
      # 2 chemical_classes * 2 broadcasts (progress) + 2 broadcasts (final) = 6
      assert_broadcasts(PopulateMoleculesJob::STREAM_NAME, 6) do
        PopulateMoleculesJob.perform_now
      end
    end

    assert_equal [ "Alkaloids", "Terpenoids" ], calls.map { |c| c[:chemical_class_name] } # ChemicalClass.ordered sorts alphabetically
    assert_equal [ "Quinine" ], calls.first[:existing_names] # Alkaloids has Quinine
    assert_equal [], calls.second[:existing_names] # Terpenoids has none initially

    assert_equal 3, Molecule.count
    france = europe.molecules.find_by!(name: "Quinine")
    assert_equal "Fifth Republic.", france.description
    assert_equal [ "republic", "nuclear power" ], france.themes

    japan = asia.molecules.find_by!(name: "Caffeine")
    assert_equal [ "island", "tech" ], japan.themes
  end



  test "perform continues to remaining chemical_classes if one chemical_class fails" do
    europe = ChemicalClass.create!(name: "Alkaloids", description: "Alkaloidsan chemical_class.")
    asia = ChemicalClass.create!(name: "Terpenoids", description: "Terpenoidsn chemical_class.")

    with_stubbed_agent_create(->(chemical_class_name:, **) {
      fake_chat = Object.new
      fake_chat.define_singleton_method(:ask) do |_prompt|
        raise "Timeout on Terpenoids" if chemical_class_name == "Terpenoids"

        OpenStruct.new(
          parsed: nil,
          content: {
            "molecules" => [
              { "name" => "Quinine", "description" => "Western Alkaloids.", "themes" => [ "republic" ] }
            ]
          }.to_json
        )
      end
      fake_chat
    }) do
      assert_broadcasts(PopulateMoleculesJob::STREAM_NAME, 6) do
        assert_nothing_raised { PopulateMoleculesJob.perform_now }
      end
    end

    assert_equal 1, Molecule.count
    assert_equal "Quinine", Molecule.first.name
  end

  private

  def with_stubbed_agent_create(callable)
    singleton = MoleculeDiscoveryAgent.singleton_class
    original = MoleculeDiscoveryAgent.method(:create!)
    singleton.define_method(:create!, &callable)
    yield
  ensure
    singleton.define_method(:create!, original)
  end
end
