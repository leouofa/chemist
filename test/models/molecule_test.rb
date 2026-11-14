# frozen_string_literal: true

require "test_helper"

class MoleculeTest < ActiveSupport::TestCase
  test "validates presence of name, description, and chemical_class" do
    molecule = Molecule.new(name: " ", description: " ")
    assert_not molecule.valid?
    assert_includes molecule.errors[:chemical_class], "must exist"
    assert_includes molecule.errors[:name], "can't be blank"
    assert_includes molecule.errors[:description], "can't be blank"
  end

  test "normalizes name, description, and themes" do
    chemical_class = ChemicalClass.create!(name: "Alkaloids", description: "Alkaloidsan chemical_class.")
    molecule = Molecule.create!(
      chemical_class: chemical_class,
      name: "  Quinine   Republic ",
      description: "  Western Alkaloidsan state.  ",
      themes: [ " nuclear ", "Maritime", "NUCLEAR", "", nil ]
    )

    assert_equal "Quinine Republic", molecule.name
    assert_equal "Western Alkaloidsan state.", molecule.description
    assert_equal [ "nuclear", "Maritime" ], molecule.themes
  end

  test "normalizes comma-separated string themes into a string array" do
    chemical_class = ChemicalClass.create!(name: "Terpenoids", description: "Terpenoidsn chemical_class.")
    molecule = Molecule.create!(
      chemical_class: chemical_class,
      name: "Caffeine",
      description: "East Terpenoidsn island state.",
      themes: "island nation, industrial export, high tech, Island Nation"
    )

    assert_equal [ "island nation", "industrial export", "high tech" ], molecule.themes
  end

  test "enforces case-insensitive uniqueness scoped per chemical_class" do
    europe = ChemicalClass.create!(name: "Alkaloids", description: "Alkaloidsan chemical_class.")
    africa = ChemicalClass.create!(name: "Flavonoids", description: "Flavonoidsn chemical_class.")

    Molecule.create!(chemical_class: europe, name: "Georgia", description: "Transcaucasian state.")

    same_chemical_class_dup = Molecule.new(chemical_class: europe, name: "georgia", description: "Duplicate.")
    assert_not same_chemical_class_dup.valid?
    assert_includes same_chemical_class_dup.errors[:name], "has already been taken"

    other_chemical_class_molecule = Molecule.new(chemical_class: africa, name: "Georgia", description: "Different region.")
    assert other_chemical_class_molecule.valid?
  end

  test "upsert_batch! inserts new molecules and updates existing ones within a chemical_class" do
    europe = ChemicalClass.create!(name: "Alkaloids", description: "Alkaloidsan chemical_class.")
    asia = ChemicalClass.create!(name: "Terpenoids", description: "Terpenoidsn chemical_class.")

    Molecule.create!(chemical_class: europe, name: "Quinine", description: "Old description", themes: [ "republic" ])
    Molecule.create!(chemical_class: asia, name: "Quinine", description: "Unrelated namesake", themes: [ "test" ])

    results = Molecule.upsert_batch!(europe, [
      { "name" => "  quinine ", "description" => "Fifth Republic.", "themes" => [ "republic", "nuclear power" ] },
      { "name" => "Morphine", "description" => "Federal republic.", "themes" => [ "manufacturing", "export" ] },
      { "name" => "", "description" => "Ignored blank name" },
      { "name" => "Italy", "description" => "   " }
    ])

    assert_equal 2, results.size
    assert_equal 2, europe.molecules.count
    assert_equal 1, asia.molecules.count

    europe_france = europe.molecules.find_by!("LOWER(name) = ?", "quinine")
    assert_equal "quinine", europe_france.name
    assert_equal "Fifth Republic.", europe_france.description
    assert_equal [ "republic", "nuclear power" ], europe_france.themes

    germany = europe.molecules.find_by!(name: "Morphine")
    assert_equal [ "manufacturing", "export" ], germany.themes
  end

  test "grouped_by_chemical_class returns chemical_class groups and molecules sorted alphabetically" do
    asia = ChemicalClass.create!(name: "Terpenoids", description: "Terpenoidsn chemical_class.")
    europe = ChemicalClass.create!(name: "Alkaloids", description: "Alkaloidsan chemical_class.")
    ChemicalClass.create!(name: "Flavonoids", description: "Empty chemical_class.")

    Molecule.create!(chemical_class: asia, name: "Caffeine", description: "East Terpenoids.", themes: [ "island" ])
    Molecule.create!(chemical_class: asia, name: "Camphor", description: "East Terpenoids.", themes: [ "manufacturing" ])
    Molecule.create!(chemical_class: europe, name: "Quinine", description: "Western Alkaloids.", themes: [ "republic" ])
    Molecule.create!(chemical_class: europe, name: "Morphine", description: "Central Alkaloids.", themes: [ "federal" ])

    groups = Molecule.grouped_by_chemical_class
    assert_equal [ "Alkaloids", "Terpenoids" ], groups.map { |chemical_class, _| chemical_class.name }
    assert_equal [ "Morphine", "Quinine" ], groups[0][1].map(&:name)
    assert_equal [ "Caffeine", "Camphor" ], groups[1][1].map(&:name)
  end

  test "destroying a chemical_class destroys its associated molecules" do
    europe = ChemicalClass.create!(name: "Alkaloids", description: "Alkaloidsan chemical_class.")
    Molecule.create!(chemical_class: europe, name: "Quinine", description: "Western Alkaloids.", themes: [ "republic" ])

    assert_difference("Molecule.count", -1) do
      europe.destroy!
    end
  end

  test "embedding_input formats chemical_class, name, description, and themes" do
    europe = ChemicalClass.create!(name: "Alkaloids", description: "Alkaloidsan chemical_class.")
    molecule = Molecule.create!(chemical_class: europe, name: "Quinine", description: "Western Alkaloids state.", themes: [ "republic", "nuclear" ])

    expected = <<~TEXT.chomp
      Molecule: Quinine (Alkaloids)
      Description: Western Alkaloids state.
      Themes: republic, nuclear
    TEXT

    assert_equal expected, molecule.embedding_input
    assert_not molecule.embedded?
  end
end
