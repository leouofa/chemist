# frozen_string_literal: true

require "test_helper"

class ChemicalClassTest < ActiveSupport::TestCase
  test "validates presence of name and description" do
    chemical_class = ChemicalClass.new(name: " ", description: " ")
    assert_not chemical_class.valid?
    assert_includes chemical_class.errors[:name], "can't be blank"
    assert_includes chemical_class.errors[:description], "can't be blank"
  end

  test "normalizes name whitespace and enforces case-insensitive uniqueness" do
    first = ChemicalClass.create!(name: "  North   America ", description: "Northern chemical_class.")
    assert_equal "North America", first.name

    duplicate = ChemicalClass.new(name: "north america", description: "Duplicate.")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end



  test "upsert_batch! inserts new chemical_classes and updates existing ones case-insensitively" do
    ChemicalClass.create!(name: "Alkaloids", description: "Old description")

    results = ChemicalClass.upsert_batch!([
      { "name" => "  alkaloids ", "description" => "Updated Alkaloids description." },
      { "name" => "Terpenoids", "description" => "Largest compound class." },
      { "name" => "", "description" => "Ignored blank name" },
      { "name" => "Flavonoids", "description" => "   " }
    ])

    assert_equal 2, results.size
    assert_equal 2, ChemicalClass.count

    alkaloids = ChemicalClass.find_by!("LOWER(name) = ?", "alkaloids")
    assert_equal "alkaloids", alkaloids.name
    assert_equal "Updated Alkaloids description.", alkaloids.description

    asia = ChemicalClass.find_by!(name: "Terpenoids")
    assert_equal "Largest compound class.", asia.description
  end
end
