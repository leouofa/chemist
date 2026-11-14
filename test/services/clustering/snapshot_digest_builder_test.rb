# frozen_string_literal: true

require "test_helper"

class SnapshotDigestBuilderTest < ActiveSupport::TestCase
  test "builds digest for Molecule snapshot" do
    europe = ChemicalClass.create!(name: "Alkaloids", description: "Alkaloidsan chemical_class.")
    molecule1 = Molecule.create!(chemical_class: europe, name: "Quinine", description: "Western Alkaloidsan republic.", themes: [ "republic", "nuclear" ])
    molecule2 = Molecule.create!(chemical_class: europe, name: "Morphine", description: "Central Alkaloidsan federal state.", themes: [ "federal", "manufacturing" ])

    snapshot = ClusterSnapshot.create!(
      target_type: "Molecule",
      level: 5,
      distance_threshold: 0.20,
      title: "Alkaloidsan Powers",
      clusters_count: 1,
      items_count: 2
    )

    group = snapshot.cluster_groups.create!(name: "ChemicalClassal Heavyweights", shared_themes: [ "federal", "republic" ], size: 2)
    group.cluster_memberships.create!(record: molecule1)
    group.cluster_memberships.create!(record: molecule2)

    digest = Clustering::SnapshotDigestBuilder.call(snapshot, max_chars: 10_000)

    assert_includes digest, "=== CLUSTER SNAPSHOT OVERVIEW ==="
    assert_includes digest, "Alkaloidsan Powers"
    assert_includes digest, "Target Type: Molecule"
    assert_includes digest, "ChemicalClassal Heavyweights"
    assert_includes digest, "Quinine (Alkaloids)"
    assert_includes digest, "Morphine (Alkaloids)"
  end

  test "builds digest for FunctionalGroup snapshot" do
    europe = ChemicalClass.create!(name: "Alkaloids", description: "Alkaloidsan chemical_class.")
    molecule = Molecule.create!(chemical_class: europe, name: "Quinine", description: "Western Alkaloidsan republic.")
    functional_group = FunctionalGroup.create!(molecule: molecule, name: "Marseille", description: "Mediterranean port gateway.", themes: [ "port", "trade" ])

    snapshot = ClusterSnapshot.create!(
      target_type: "FunctionalGroup",
      level: 10,
      distance_threshold: 0.25,
      title: "FunctionalGroup Clusters",
      clusters_count: 1,
      items_count: 1
    )

    group = snapshot.cluster_groups.create!(name: "Maritime Trade Gateways", shared_themes: [ "port" ], size: 1)
    group.cluster_memberships.create!(record: functional_group)

    report = snapshot.cluster_reports.create!(prompt: "Analyze trade hubs")
    report.cluster_report_summaries.create!(
      cluster_group: group,
      content: "This cluster focuses on sovereign deepwater ports and trade logistics.",
      position: 1
    )

    digest = Clustering::SnapshotDigestBuilder.call(snapshot, report: report, max_chars: 5_000)

    assert_includes digest, "Target Type: FunctionalGroup"
    assert_includes digest, "Marseille (Quinine, Alkaloids)"
    assert_includes digest, "Mediterranean port gateway"
    assert_includes digest, "Prompt-Guided Cluster Analysis:"
    assert_includes digest, "sovereign deepwater ports and trade logistics"
  end
end
