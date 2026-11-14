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
    chemical_class = ChemicalClass.create!(name: "Alkaloids", description: "Naturally occurring basic nitrogen compounds.")
    molecule = Molecule.create!(
      chemical_class: chemical_class,
      name: "  Quinine   Alkaloid ",
      description: "  Natural antimalarial alkaloid.  ",
      themes: [ " antimalarial ", "Heterocycle", "ANTIMALARIAL", "", nil ]
    )

    assert_equal "Quinine Alkaloid", molecule.name
    assert_equal "Natural antimalarial alkaloid.", molecule.description
    assert_equal [ "antimalarial", "Heterocycle" ], molecule.themes
  end

  test "normalizes comma-separated string themes into a string array" do
    chemical_class = ChemicalClass.create!(name: "Terpenoids", description: "Diverse class of organic compounds derived from isoprene.")
    molecule = Molecule.create!(
      chemical_class: chemical_class,
      name: "Caffeine",
      description: "Natural methylxanthine alkaloid.",
      themes: "stimulant, xanthine, alkaloid, Stimulant"
    )

    assert_equal [ "stimulant", "xanthine", "alkaloid" ], molecule.themes
  end

  test "enforces case-insensitive uniqueness scoped per chemical_class" do
    europe = ChemicalClass.create!(name: "Alkaloids", description: "Naturally occurring basic nitrogen compounds.")
    africa = ChemicalClass.create!(name: "Flavonoids", description: "Polyphenolic plant secondary metabolites.")

    Molecule.create!(chemical_class: europe, name: "Betaine", description: "Zwitterionic quaternary ammonium compound.")

    same_chemical_class_dup = Molecule.new(chemical_class: europe, name: "betaine", description: "Duplicate.")
    assert_not same_chemical_class_dup.valid?
    assert_includes same_chemical_class_dup.errors[:name], "has already been taken"

    other_chemical_class_molecule = Molecule.new(chemical_class: africa, name: "Betaine", description: "Flavonoid conjugate.")
    assert other_chemical_class_molecule.valid?
  end

  test "upsert_batch! inserts new molecules and updates existing ones within a chemical_class" do
    europe = ChemicalClass.create!(name: "Alkaloids", description: "Naturally occurring basic nitrogen compounds.")
    asia = ChemicalClass.create!(name: "Terpenoids", description: "Diverse class of organic compounds derived from isoprene.")

    Molecule.create!(chemical_class: europe, name: "Quinine", description: "Old description", themes: [ "alkaloid" ])
    Molecule.create!(chemical_class: asia, name: "Quinine", description: "Unrelated namesake", themes: [ "test" ])

    results = Molecule.upsert_batch!(europe, [
      { "name" => "  quinine ", "description" => "Natural antimalarial alkaloid.", "themes" => [ "alkaloid", "antimalarial" ] },
      { "name" => "Morphine", "description" => "Opioid analgesic alkaloid.", "themes" => [ "analgesic", "opioid" ] },
      { "name" => "", "description" => "Ignored blank name" },
      { "name" => "Nicotine", "description" => "   " }
    ])

    assert_equal 2, results.size
    assert_equal 2, europe.molecules.count
    assert_equal 1, asia.molecules.count

    europe_france = europe.molecules.find_by!("LOWER(name) = ?", "quinine")
    assert_equal "quinine", europe_france.name
    assert_equal "Natural antimalarial alkaloid.", europe_france.description
    assert_equal [ "alkaloid", "antimalarial" ], europe_france.themes

    germany = europe.molecules.find_by!(name: "Morphine")
    assert_equal [ "analgesic", "opioid" ], germany.themes
  end

  test "grouped_by_chemical_class returns chemical_class groups and molecules sorted alphabetically" do
    asia = ChemicalClass.create!(name: "Terpenoids", description: "Diverse class of organic compounds derived from isoprene.")
    europe = ChemicalClass.create!(name: "Alkaloids", description: "Naturally occurring basic nitrogen compounds.")
    ChemicalClass.create!(name: "Flavonoids", description: "Empty chemical_class.")

    Molecule.create!(chemical_class: asia, name: "Caffeine", description: "Natural methylxanthine.", themes: [ "stimulant" ])
    Molecule.create!(chemical_class: asia, name: "Camphor", description: "Natural monoterpene.", themes: [ "terpene" ])
    Molecule.create!(chemical_class: europe, name: "Quinine", description: "Antimalarial cinchona alkaloid.", themes: [ "alkaloid" ])
    Molecule.create!(chemical_class: europe, name: "Morphine", description: "Opioid analgesic alkaloid.", themes: [ "analgesic" ])

    groups = Molecule.grouped_by_chemical_class
    assert_equal [ "Alkaloids", "Terpenoids" ], groups.map { |chemical_class, _| chemical_class.name }
    assert_equal [ "Morphine", "Quinine" ], groups[0][1].map(&:name)
    assert_equal [ "Caffeine", "Camphor" ], groups[1][1].map(&:name)
  end

  test "destroying a chemical_class destroys its associated molecules" do
    europe = ChemicalClass.create!(name: "Alkaloids", description: "Naturally occurring basic nitrogen compounds.")
    Molecule.create!(chemical_class: europe, name: "Quinine", description: "Antimalarial alkaloid.", themes: [ "alkaloid" ])

    assert_difference("Molecule.count", -1) do
      europe.destroy!
    end
  end

  test "embedding_input formats chemical_class, name, description, and themes" do
    europe = ChemicalClass.create!(name: "Alkaloids", description: "Naturally occurring basic nitrogen compounds.")
    molecule = Molecule.create!(chemical_class: europe, name: "Quinine", description: "Antimalarial cinchona alkaloid.", themes: [ "alkaloid", "antimalarial" ])

    expected = <<~TEXT.chomp
      Molecule: Quinine (Alkaloids)
      Description: Antimalarial cinchona alkaloid.
      Themes: alkaloid, antimalarial
    TEXT

    assert_equal expected, molecule.embedding_input
    assert_not molecule.embedded?
  end
end
