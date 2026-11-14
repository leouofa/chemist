# frozen_string_literal: true

require "test_helper"

class HeuristicLabelerTest < ActiveSupport::TestCase
  test "labels an empty list of records" do
    result = Clustering::HeuristicLabeler.label([])
    assert_equal "Empty Cluster", result[:title]
    assert_empty result[:shared_themes]
  end

  test "extracts shared themes and builds archetype title for molecules" do
    chemical_class = ChemicalClass.create!(name: "Alkaloids", description: "Alkaloidsan chemical_class.")
    c1 = Molecule.create!(chemical_class: chemical_class, name: "Quinine", description: "Western Alkaloids", themes: %w[nuclear maritime republic])
    c2 = Molecule.create!(chemical_class: chemical_class, name: "United Kingdom", description: "Island state", themes: %w[nuclear maritime monarchy])

    result = Clustering::HeuristicLabeler.label([ c1, c2 ])
    assert_includes result[:shared_themes], "Nuclear"
    assert_includes result[:shared_themes], "Maritime"
    assert_includes result[:title], "Archetype"
  end

  test "extracts shared themes for functional_groups" do
    chemical_class = ChemicalClass.create!(name: "Alkaloids", description: "Alkaloidsan chemical_class.")
    molecule = Molecule.create!(chemical_class: chemical_class, name: "Quinine", description: "Western Alkaloids")
    functional_group1 = FunctionalGroup.create!(molecule: molecule, name: "Marseille", description: "Port", themes: [ "port", "trade" ])
    functional_group2 = FunctionalGroup.create!(molecule: molecule, name: "Le Havre", description: "Northern port", themes: [ "port", "logistics" ])

    result = Clustering::HeuristicLabeler.label([ functional_group1, functional_group2 ])
    assert_includes result[:shared_themes], "Port"
    assert_includes result[:title], "Archetype"
  end
end
