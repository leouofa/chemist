# frozen_string_literal: true

require "test_helper"

class HeuristicLabelerTest < ActiveSupport::TestCase
  test "labels an empty list of records" do
    result = Clustering::HeuristicLabeler.label([])
    assert_equal "Empty Cluster", result[:title]
    assert_empty result[:shared_themes]
  end

  test "extracts shared themes and builds archetype title for molecules" do
    chemical_class = ChemicalClass.create!(name: "Alkaloids", description: "Naturally occurring basic nitrogen compounds.")
    c1 = Molecule.create!(chemical_class: chemical_class, name: "Quinine", description: "Natural antimalarial alkaloid", themes: %w[heterocycle basic alkaloid])
    c2 = Molecule.create!(chemical_class: chemical_class, name: "Cinchonine", description: "Cinchona alkaloid", themes: %w[heterocycle basic isomer])

    result = Clustering::HeuristicLabeler.label([ c1, c2 ])
    assert_includes result[:shared_themes], "Heterocycle"
    assert_includes result[:shared_themes], "Basic"
    assert_includes result[:title], "Archetype"
  end

  test "extracts shared themes for functional_groups" do
    chemical_class = ChemicalClass.create!(name: "Alkaloids", description: "Naturally occurring basic nitrogen compounds.")
    molecule = Molecule.create!(chemical_class: chemical_class, name: "Quinine", description: "Natural antimalarial alkaloid")
    functional_group1 = FunctionalGroup.create!(molecule: molecule, name: "Quinoline Ring", description: "Aromatic heterocycle", themes: [ "heterocycle", "aromatic" ])
    functional_group2 = FunctionalGroup.create!(molecule: molecule, name: "Pyridine Ring", description: "Six-membered aromatic ring", themes: [ "heterocycle", "nitrogen" ])

    result = Clustering::HeuristicLabeler.label([ functional_group1, functional_group2 ])
    assert_includes result[:shared_themes], "Heterocycle"
    assert_includes result[:title], "Archetype"
  end
end
