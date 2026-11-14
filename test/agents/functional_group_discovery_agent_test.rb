# frozen_string_literal: true

require "test_helper"

class FunctionalGroupDiscoveryAgentTest < ActiveSupport::TestCase
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

  test "create! includes molecule context, chemical_class name, existing functional_group names, and Quinuclidine JSON example" do
    chat = FunctionalGroupDiscoveryAgent.create!(
      molecule_name: "Quinine",
      molecule_description: "Natural antimalarial alkaloid.",
      molecule_themes: [ "antimalarial", "quinoline core", "chiral catalyst" ],
      chemical_class_name: "Alkaloids",
      existing_names: [ "Quinoline Ring", "Quinuclidine Nitrogen" ]
    )

    assert chat.persisted?
    assert_nil chat.schema

    system_message = chat.messages.find_by!(role: "system")
    assert_includes system_message.content, "Quinine"
    assert_includes system_message.content, "Alkaloids"
    assert_includes system_message.content, "Natural antimalarial alkaloid."
    assert_includes system_message.content, "antimalarial, quinoline core, chiral catalyst"
    assert_includes system_message.content, "Quinoline Ring, Quinuclidine Nitrogen"
    assert_includes system_message.content, "Quinuclidine Bridgehead Nitrogen"
    assert_includes system_message.content, '"functional_groups"'
    assert_includes system_message.content, '"themes"'
  end
end
