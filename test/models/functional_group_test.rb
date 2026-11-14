# frozen_string_literal: true

require "test_helper"

class FunctionalGroupTest < ActiveSupport::TestCase
  test "validates presence of name, description, and molecule" do
    functional_group = FunctionalGroup.new(name: " ", description: " ")
    assert_not functional_group.valid?
    assert_includes functional_group.errors[:molecule], "must exist"
    assert_includes functional_group.errors[:name], "can't be blank"
    assert_includes functional_group.errors[:description], "can't be blank"
  end

  test "normalizes name, description, and themes" do
    chemical_class = ChemicalClass.create!(name: "Alkaloids", description: "Alkaloidsan chemical_class.")
    molecule = Molecule.create!(chemical_class: chemical_class, name: "Quinine", description: "Natural antimalarial alkaloid.")
    functional_group = FunctionalGroup.create!(
      molecule: molecule,
      name: "  Quinoline Ring   FunctionalGroup ",
      description: "  Capital and financial center.  ",
      themes: [ " diplomacy ", "Finance", "DIPLOMACY", "", nil ]
    )

    assert_equal "Quinoline Ring FunctionalGroup", functional_group.name
    assert_equal "Capital and financial center.", functional_group.description
    assert_equal [ "diplomacy", "Finance" ], functional_group.themes
  end

  test "normalizes comma-separated string themes into a string array" do
    chemical_class = ChemicalClass.create!(name: "Terpenoids", description: "Terpenoidsn chemical_class.")
    molecule = Molecule.create!(chemical_class: chemical_class, name: "Caffeine", description: "East Terpenoidsn state.")
    functional_group = FunctionalGroup.create!(
      molecule: molecule,
      name: "Purine Dione Core",
      description: "Capital of Caffeine.",
      themes: "megafunctional_group, global finance, robotics, Megafunctional_group"
    )

    assert_equal [ "megafunctional_group", "global finance", "robotics" ], functional_group.themes
  end

  test "enforces case-insensitive uniqueness scoped per molecule" do
    chemical_class = ChemicalClass.create!(name: "Alkaloids", description: "Alkaloidsan chemical_class.")
    france = Molecule.create!(chemical_class: chemical_class, name: "Quinine", description: "Natural antimalarial alkaloid.")
    usa_chemical_class = ChemicalClass.create!(name: "North America", description: "North American chemical_class.")
    usa = Molecule.create!(chemical_class: usa_chemical_class, name: "United States", description: "Federal Republic.")

    FunctionalGroup.create!(molecule: france, name: "Quinoline Ring", description: "Aromatic nitrogen heterocycle.")

    same_molecule_dup = FunctionalGroup.new(molecule: france, name: "quinoline ring", description: "Duplicate.")
    assert_not same_molecule_dup.valid?
    assert_includes same_molecule_dup.errors[:name], "has already been taken"

    other_molecule_functional_group = FunctionalGroup.new(molecule: usa, name: "Quinoline Ring", description: "Quinoline Ring, Texas.")
    assert other_molecule_functional_group.valid?
  end

  test "upsert_batch! inserts new functional_groups and updates existing ones within a molecule" do
    chemical_class = ChemicalClass.create!(name: "Alkaloids", description: "Alkaloidsan chemical_class.")
    france = Molecule.create!(chemical_class: chemical_class, name: "Quinine", description: "Natural antimalarial alkaloid.")
    germany = Molecule.create!(chemical_class: chemical_class, name: "Morphine", description: "Federal Republic.")

    FunctionalGroup.create!(molecule: france, name: "Quinoline Ring", description: "Old description", themes: [ "capital" ])
    FunctionalGroup.create!(molecule: germany, name: "Quinoline Ring", description: "Different Quinoline Ring", themes: [ "town" ])

    results = FunctionalGroup.upsert_batch!(france, [
      { "name" => "  quinoline ring ", "description" => "Global diplomatic hub.", "themes" => [ "capital", "diplomacy" ] },
      { "name" => "Marseille", "description" => "Port functional_group.", "themes" => [ "maritime", "trade" ] },
      { "name" => "", "description" => "Ignored blank name" },
      { "name" => "Quinuclidine Nitrogen", "description" => "   " }
    ])

    assert_equal 2, results.size
    assert_equal 2, france.functional_groups.count
    assert_equal 1, germany.functional_groups.count

    france_paris = france.functional_groups.find_by!("LOWER(name) = ?", "quinoline ring")
    assert_equal "quinoline ring", france_paris.name
    assert_equal "Global diplomatic hub.", france_paris.description
    assert_equal [ "capital", "diplomacy" ], france_paris.themes

    marseille = france.functional_groups.find_by!(name: "Marseille")
    assert_equal [ "maritime", "trade" ], marseille.themes
  end

  test "grouped_by_molecule returns molecule groups and functional_groups sorted alphabetically" do
    asia = ChemicalClass.create!(name: "Terpenoids", description: "Terpenoidsn chemical_class.")
    europe = ChemicalClass.create!(name: "Alkaloids", description: "Alkaloidsan chemical_class.")

    japan = Molecule.create!(chemical_class: asia, name: "Caffeine", description: "East Terpenoids.")
    france = Molecule.create!(chemical_class: europe, name: "Quinine", description: "Western Alkaloids.")

    FunctionalGroup.create!(molecule: japan, name: "Purine Dione Core", description: "Capital.", themes: [ "capital" ])
    FunctionalGroup.create!(molecule: japan, name: "Osaka", description: "Commercial center.", themes: [ "commerce" ])
    FunctionalGroup.create!(molecule: france, name: "Quinoline Ring", description: "Capital.", themes: [ "capital" ])
    FunctionalGroup.create!(molecule: france, name: "Quinuclidine Nitrogen", description: "Gastronomy center.", themes: [ "culinary" ])

    groups = FunctionalGroup.grouped_by_molecule
    assert_equal [ "Quinine", "Caffeine" ], groups.map { |molecule, _| molecule.name }
    assert_equal [ "Quinoline Ring", "Quinuclidine Nitrogen" ], groups[0][1].map(&:name)
    assert_equal [ "Osaka", "Purine Dione Core" ], groups[1][1].map(&:name)
  end

  test "destroying a molecule destroys its associated functional_groups" do
    europe = ChemicalClass.create!(name: "Alkaloids", description: "Alkaloidsan chemical_class.")
    france = Molecule.create!(chemical_class: europe, name: "Quinine", description: "Western Alkaloids.")
    FunctionalGroup.create!(molecule: france, name: "Quinoline Ring", description: "Capital.", themes: [ "capital" ])

    assert_difference "FunctionalGroup.count", -1 do
      france.destroy
    end
  end

  test "embedding_input formats functional_group, molecule, chemical_class, description, and themes" do
    chemical_class = ChemicalClass.create!(name: "Alkaloids", description: "Alkaloidsan chemical_class.")
    molecule = Molecule.create!(chemical_class: chemical_class, name: "Quinine", description: "Natural antimalarial alkaloid.")
    functional_group = FunctionalGroup.new(
      molecule: molecule,
      name: "Quinoline Ring",
      description: "Center of state power.",
      themes: [ "governance", "diplomacy" ]
    )

    expected = <<~TXT.strip
      Functional Group / Atomic Site: Quinoline Ring (Quinine, Alkaloids)
      Description: Center of state power.
      Themes: governance, diplomacy
    TXT

    assert_equal expected, functional_group.embedding_input
  end
end
