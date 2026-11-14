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
    chemical_class = ChemicalClass.create!(name: "Alkaloids", description: "Naturally occurring basic nitrogen compounds.")
    molecule = Molecule.create!(chemical_class: chemical_class, name: "Quinine", description: "Natural antimalarial alkaloid.")
    functional_group = FunctionalGroup.create!(
      molecule: molecule,
      name: "  Quinoline Ring   FunctionalGroup ",
      description: "  Aromatic nitrogen heterocycle.  ",
      themes: [ " heterocycle ", "Amine", "HETEROCYCLE", "", nil ]
    )

    assert_equal "Quinoline Ring FunctionalGroup", functional_group.name
    assert_equal "Aromatic nitrogen heterocycle.", functional_group.description
    assert_equal [ "heterocycle", "Amine" ], functional_group.themes
  end

  test "normalizes comma-separated string themes into a string array" do
    chemical_class = ChemicalClass.create!(name: "Terpenoids", description: "Diverse class of organic compounds derived from isoprene.")
    molecule = Molecule.create!(chemical_class: chemical_class, name: "Caffeine", description: "Natural methylxanthine alkaloid.")
    functional_group = FunctionalGroup.create!(
      molecule: molecule,
      name: "Purine Dione Core",
      description: "Bicyclic aromatic functional core.",
      themes: "purine, xanthine, core, Purine"
    )

    assert_equal [ "purine", "xanthine", "core" ], functional_group.themes
  end

  test "enforces case-insensitive uniqueness scoped per molecule" do
    chemical_class = ChemicalClass.create!(name: "Alkaloids", description: "Naturally occurring basic nitrogen compounds.")
    france = Molecule.create!(chemical_class: chemical_class, name: "Quinine", description: "Natural antimalarial alkaloid.")
    usa_chemical_class = ChemicalClass.create!(name: "Flavonoids", description: "Polyphenolic plant secondary metabolites.")
    usa = Molecule.create!(chemical_class: usa_chemical_class, name: "Quercetin", description: "Flavonol compound.")

    FunctionalGroup.create!(molecule: france, name: "Quinoline Ring", description: "Aromatic nitrogen heterocycle.")

    same_molecule_dup = FunctionalGroup.new(molecule: france, name: "quinoline ring", description: "Duplicate.")
    assert_not same_molecule_dup.valid?
    assert_includes same_molecule_dup.errors[:name], "has already been taken"

    other_molecule_functional_group = FunctionalGroup.new(molecule: usa, name: "Quinoline Ring", description: "Synthetic quinoline derivative.")
    assert other_molecule_functional_group.valid?
  end

  test "upsert_batch! inserts new functional_groups and updates existing ones within a molecule" do
    chemical_class = ChemicalClass.create!(name: "Alkaloids", description: "Naturally occurring basic nitrogen compounds.")
    france = Molecule.create!(chemical_class: chemical_class, name: "Quinine", description: "Natural antimalarial alkaloid.")
    germany = Molecule.create!(chemical_class: chemical_class, name: "Morphine", description: "Opioid analgesic alkaloid.")

    FunctionalGroup.create!(molecule: france, name: "Quinoline Ring", description: "Old description", themes: [ "core" ])
    FunctionalGroup.create!(molecule: germany, name: "Quinoline Ring", description: "Different Quinoline Ring", themes: [ "substituent" ])

    results = FunctionalGroup.upsert_batch!(france, [
      { "name" => "  quinoline ring ", "description" => "Aromatic nitrogen heterocycle.", "themes" => [ "heterocycle", "aromatic" ] },
      { "name" => "Quinuclidine", "description" => "Bicyclic tertiary amine.", "themes" => [ "amine", "bicyclic" ] },
      { "name" => "", "description" => "Ignored blank name" },
      { "name" => "Quinuclidine Nitrogen", "description" => "   " }
    ])

    assert_equal 2, results.size
    assert_equal 2, france.functional_groups.count
    assert_equal 1, germany.functional_groups.count

    france_paris = france.functional_groups.find_by!("LOWER(name) = ?", "quinoline ring")
    assert_equal "quinoline ring", france_paris.name
    assert_equal "Aromatic nitrogen heterocycle.", france_paris.description
    assert_equal [ "heterocycle", "aromatic" ], france_paris.themes

    quinuclidine = france.functional_groups.find_by!(name: "Quinuclidine")
    assert_equal [ "amine", "bicyclic" ], quinuclidine.themes
  end

  test "grouped_by_molecule returns molecule groups and functional_groups sorted alphabetically" do
    asia = ChemicalClass.create!(name: "Terpenoids", description: "Diverse class of organic compounds derived from isoprene.")
    europe = ChemicalClass.create!(name: "Alkaloids", description: "Naturally occurring basic nitrogen compounds.")

    caffeine = Molecule.create!(chemical_class: asia, name: "Caffeine", description: "Natural methylxanthine alkaloid.")
    quinine = Molecule.create!(chemical_class: europe, name: "Quinine", description: "Natural antimalarial alkaloid.")

    FunctionalGroup.create!(molecule: caffeine, name: "Purine Dione Core", description: "Core.", themes: [ "core" ])
    FunctionalGroup.create!(molecule: caffeine, name: "Imidazole Ring", description: "Five-membered aromatic ring.", themes: [ "heterocycle" ])
    FunctionalGroup.create!(molecule: quinine, name: "Quinoline Ring", description: "Core.", themes: [ "core" ])
    FunctionalGroup.create!(molecule: quinine, name: "Quinuclidine Nitrogen", description: "Bridgehead nitrogen atom.", themes: [ "amine" ])

    groups = FunctionalGroup.grouped_by_molecule
    assert_equal [ "Quinine", "Caffeine" ], groups.map { |molecule, _| molecule.name }
    assert_equal [ "Quinoline Ring", "Quinuclidine Nitrogen" ], groups[0][1].map(&:name)
    assert_equal [ "Imidazole Ring", "Purine Dione Core" ], groups[1][1].map(&:name)
  end

  test "destroying a molecule destroys its associated functional_groups" do
    europe = ChemicalClass.create!(name: "Alkaloids", description: "Naturally occurring basic nitrogen compounds.")
    quinine = Molecule.create!(chemical_class: europe, name: "Quinine", description: "Natural antimalarial alkaloid.")
    FunctionalGroup.create!(molecule: quinine, name: "Quinoline Ring", description: "Core.", themes: [ "core" ])

    assert_difference "FunctionalGroup.count", -1 do
      quinine.destroy
    end
  end

  test "embedding_input formats functional_group, molecule, chemical_class, description, and themes" do
    chemical_class = ChemicalClass.create!(name: "Alkaloids", description: "Naturally occurring basic nitrogen compounds.")
    molecule = Molecule.create!(chemical_class: chemical_class, name: "Quinine", description: "Natural antimalarial alkaloid.")
    functional_group = FunctionalGroup.new(
      molecule: molecule,
      name: "Quinoline Ring",
      description: "Bicyclic aromatic nitrogen heterocycle.",
      themes: [ "heterocycle", "aromatic" ]
    )

    expected = <<~TXT.strip
      Functional Group / Atomic Site: Quinoline Ring (Quinine, Alkaloids)
      Description: Bicyclic aromatic nitrogen heterocycle.
      Themes: heterocycle, aromatic
    TXT

    assert_equal expected, functional_group.embedding_input
  end
end
