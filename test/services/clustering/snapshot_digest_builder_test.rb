# frozen_string_literal: true

require "test_helper"

class SnapshotDigestBuilderTest < ActiveSupport::TestCase
  test "builds digest for Molecule snapshot" do
    europe = ChemicalClass.create!(name: "Alkaloids", description: "Naturally occurring basic nitrogen compounds.")
    molecule1 = Molecule.create!(chemical_class: europe, name: "Quinine", description: "Natural antimalarial alkaloid.", themes: [ "alkaloid", "antimalarial" ])
    molecule2 = Molecule.create!(chemical_class: europe, name: "Morphine", description: "Opioid analgesic alkaloid.", themes: [ "analgesic", "opioid" ])

    snapshot = ClusterSnapshot.create!(
      target_type: "Molecule",
      level: 5,
      distance_threshold: 0.20,
      title: "Alkaloid Scaffolds",
      clusters_count: 1,
      items_count: 2
    )

    group = snapshot.cluster_groups.create!(name: "Alkaloid Core Motifs", shared_themes: [ "alkaloid", "analgesic" ], size: 2)
    group.cluster_memberships.create!(record: molecule1)
    group.cluster_memberships.create!(record: molecule2)

    digest = Clustering::SnapshotDigestBuilder.call(snapshot, max_chars: 10_000)

    assert_includes digest, "=== CLUSTER SNAPSHOT OVERVIEW ==="
    assert_includes digest, "Alkaloid Scaffolds"
    assert_includes digest, "Target Type: Molecule"
    assert_includes digest, "Alkaloid Core Motifs"
    assert_includes digest, "Quinine (Alkaloids)"
    assert_includes digest, "Morphine (Alkaloids)"
  end

  test "builds digest for FunctionalGroup snapshot" do
    europe = ChemicalClass.create!(name: "Alkaloids", description: "Naturally occurring basic nitrogen compounds.")
    molecule = Molecule.create!(chemical_class: europe, name: "Quinine", description: "Natural antimalarial alkaloid.")
    functional_group = FunctionalGroup.create!(molecule: molecule, name: "Quinoline Ring", description: "Bicyclic aromatic nitrogen heterocycle.", themes: [ "heterocycle", "aromatic" ])

    snapshot = ClusterSnapshot.create!(
      target_type: "FunctionalGroup",
      level: 10,
      distance_threshold: 0.25,
      title: "FunctionalGroup Clusters",
      clusters_count: 1,
      items_count: 1
    )

    group = snapshot.cluster_groups.create!(name: "Aromatic Nitrogen Heterocycles", shared_themes: [ "heterocycle" ], size: 1)
    group.cluster_memberships.create!(record: functional_group)

    report = snapshot.cluster_reports.create!(prompt: "Analyze nitrogen heterocycles")
    report.cluster_report_summaries.create!(
      cluster_group: group,
      content: "This cluster focuses on aromatic nitrogen heterocyclic systems.",
      position: 1
    )

    digest = Clustering::SnapshotDigestBuilder.call(snapshot, report: report, max_chars: 5_000)

    assert_includes digest, "Target Type: FunctionalGroup"
    assert_includes digest, "Quinoline Ring (Quinine, Alkaloids)"
    assert_includes digest, "Bicyclic aromatic nitrogen heterocycle"
    assert_includes digest, "Prompt-Guided Cluster Analysis:"
    assert_includes digest, "aromatic nitrogen heterocyclic systems"
  end
end
