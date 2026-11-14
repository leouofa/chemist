# frozen_string_literal: true

require "test_helper"
require "ostruct"

class PopulateChemicalClassesJobTest < ActiveSupport::TestCase
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

  test "perform runs agent, upserts chemical_classes, and broadcasts Turbo Stream updates" do
    ChemicalClass.create!(name: "Alkaloids", description: "Initial Alkaloids description")

    fake_response = OpenStruct.new(
      parsed: nil,
      content: <<~TEXT
        <think>Let me list major chemical_classes.</think>
        ```json
        {
          "chemical_classes": [
            { "name": "Alkaloids", "description": "Alkaloidsan chemical_class with supranational institutions." },
            { "name": "Terpenoids", "description": "Vast landmass spanning major geopolitical power centers." }
          ]
        }
        ```
      TEXT
    )

    received_existing_names = nil
    fake_chat = Object.new
    fake_chat.define_singleton_method(:ask) { |_prompt| fake_response }

    with_stubbed_agent_create(->(existing_names:) {
      received_existing_names = existing_names
      fake_chat
    }) do
      assert_broadcasts(PopulateChemicalClassesJob::STREAM_NAME, 2) do
        PopulateChemicalClassesJob.perform_now
      end
    end

    assert_equal [ "Alkaloids" ], received_existing_names
    assert_equal 2, ChemicalClass.count
    assert_equal "Alkaloidsan chemical_class with supranational institutions.", ChemicalClass.find_by!(name: "Alkaloids").description
    assert_equal "Vast landmass spanning major geopolitical power centers.", ChemicalClass.find_by!(name: "Terpenoids").description
  end

  test "perform broadcasts error status and recovers gracefully when LLM fails" do
    fake_chat = Object.new
    fake_chat.define_singleton_method(:ask) { |_prompt| raise "LLM connection refused" }

    with_stubbed_agent_create(->(**) { fake_chat }) do
      assert_broadcasts(PopulateChemicalClassesJob::STREAM_NAME, 2) do
        assert_nothing_raised { PopulateChemicalClassesJob.perform_now }
      end
    end
  end

  test "perform broadcasts error status when LLM returns invalid non-JSON text" do
    fake_response = OpenStruct.new(parsed: nil, content: "Sorry, I cannot help with that.")
    fake_chat = Object.new
    fake_chat.define_singleton_method(:ask) { |_prompt| fake_response }

    with_stubbed_agent_create(->(**) { fake_chat }) do
      assert_broadcasts(PopulateChemicalClassesJob::STREAM_NAME, 2) do
        assert_nothing_raised { PopulateChemicalClassesJob.perform_now }
      end
    end

    assert_equal 0, ChemicalClass.count
  end

  private

  def with_stubbed_agent_create(callable)
    singleton = ChemicalClassDiscoveryAgent.singleton_class
    original = ChemicalClassDiscoveryAgent.method(:create!)
    singleton.define_method(:create!, &callable)
    yield
  ensure
    singleton.define_method(:create!, original)
  end
end
