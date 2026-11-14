# frozen_string_literal: true

require "test_helper"

class MoleculeDiscoveryAgentTest < ActiveSupport::TestCase
  setup do
    @previous_ollama_api_base = RubyLLM.config.ollama_api_base
    @previous_default_model = RubyLLM.config.default_model
    @model_id = ENV["OLLAMA_MODEL"].presence || "Qwen3.6-35B-A3B-NVFP4"

    RubyLLM.configure do |config|
      config.ollama_api_base = ENV["OLLAMA_API_BASE"].presence || "http://localhost:11434/v1"
      config.default_model = @model_id
    end

    Llm::ModelRegistry.ensure_configured_model!(model_id: @model_id)
  end

  teardown do
    RubyLLM.configure do |config|
      config.ollama_api_base = @previous_ollama_api_base
      config.default_model = @previous_default_model
    end
  end

  test "create! includes chemical_class context, existing molecule names, and JSON schema instructions" do
    chat = MoleculeDiscoveryAgent.create!(
      chemical_class_name: "Alkaloids",
      chemical_class_description: "Major class of basic nitrogenous plant compounds.",
      existing_names: [ "Quinine", "Morphine" ]
    )

    assert chat.persisted?
    assert_nil chat.schema

    system_message = chat.messages.find_by!(role: "system")
    assert_includes system_message.content, "Alkaloids"
    assert_includes system_message.content, "Major class of basic nitrogenous plant compounds."
    assert_includes system_message.content, "Quinine, Morphine"
    assert_includes system_message.content, '"molecules"'
    assert_includes system_message.content, '"themes"'
  end
end
