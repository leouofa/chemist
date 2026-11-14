# frozen_string_literal: true

require "test_helper"
require "ostruct"

class Llm::JsonResponseParserTest < ActiveSupport::TestCase
  test "extract_list prefers response.parsed when present" do
    response = OpenStruct.new(parsed: { "molecules" => [ { "name" => "Quinine" } ] }, content: "ignored")
    assert_equal [ { "name" => "Quinine" } ], Llm::JsonResponseParser.extract_list(response, key: "molecules")
  end

  test "extract_list strips think tags and markdown fences" do
    response = OpenStruct.new(
      parsed: nil,
      content: <<~TEXT
        <think>Thinking about sovereign states...</think>
        ```json
        { "molecules": [{ "name": "Morphine", "themes": ["federal"] }] }
        ```
      TEXT
    )

    assert_equal [ { "name" => "Morphine", "themes" => [ "federal" ] } ],
                 Llm::JsonResponseParser.extract_list(response, key: "molecules")
  end

  test "extract_list falls back to embedded JSON and returns empty array for invalid text" do
    embedded_array = OpenStruct.new(parsed: nil, content: "Here is the list: [{\"name\":\"Caffeine\"}] Hope that helps!")
    assert_equal [ { "name" => "Caffeine" } ], Llm::JsonResponseParser.extract_list(embedded_array, key: "molecules")

    embedded_object = OpenStruct.new(parsed: nil, content: "[Note] {\"molecules\":[{\"name\":\"Penicillin G\"}]} Done.")
    assert_equal [ { "name" => "Penicillin G" } ], Llm::JsonResponseParser.extract_list(embedded_object, key: "molecules")

    invalid = OpenStruct.new(parsed: nil, content: "Not JSON at all")
    assert_equal [], Llm::JsonResponseParser.extract_list(invalid, key: "molecules")
  end

  test "extract_hash parses flat JSON objects and unwraps optional nested key" do
    flat = OpenStruct.new(
      parsed: nil,
      content: <<~TEXT
        <think>Analyzing statecraft themes...</think>
        ```json
        {
          "Maritime Trade Network": "Control of key shipping lanes and deepwater ports.",
          "Industrial Export Base": "High-value manufacturing and technology supply chains."
        }
        ```
      TEXT
    )

    assert_equal(
      {
        "Maritime Trade Network" => "Control of key shipping lanes and deepwater ports.",
        "Industrial Export Base" => "High-value manufacturing and technology supply chains."
      },
      Llm::JsonResponseParser.extract_hash(flat, key: "themes")
    )

    wrapped = OpenStruct.new(
      parsed: { "themes" => { "Sovereignty" => "Constitutional governance." } },
      content: "ignored"
    )
    assert_equal({ "Sovereignty" => "Constitutional governance." }, Llm::JsonResponseParser.extract_hash(wrapped, key: "themes"))

    invalid = OpenStruct.new(parsed: nil, content: "No JSON object here")
    assert_equal({}, Llm::JsonResponseParser.extract_hash(invalid, key: "themes"))
  end
end
