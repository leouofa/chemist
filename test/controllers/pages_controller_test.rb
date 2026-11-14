# frozen_string_literal: true

require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "home renders empty state and populate button when no chemical_classes exist" do
    get root_url

    assert_response :success
    assert_select "h1", "Chemical Classes"
    assert_select "button", /Discover|Populate/
    assert_match "No chemical classes yet", response.body
  end

  test "home lists all chemical_classes ordered by name" do
    ChemicalClass.create!(name: "Alkaloids", description: "Naturally occurring basic nitrogen compounds.")
    ChemicalClass.create!(name: "Terpenoids", description: "Diverse class of organic compounds derived from isoprene.")

    get root_url

    assert_response :success
    assert_select "article h2", count: 2
    assert_operator response.body.index("Alkaloids"), :<, response.body.index("Terpenoids")
    assert_match "Naturally occurring basic nitrogen compounds.", response.body
    assert_match "Diverse class of organic compounds derived from isoprene.", response.body
  end

  test "molecules renders empty state and populate button when no molecules exist" do
    get molecules_url

    assert_response :success
    assert_select "h1", "Molecules / Compounds"
    assert_select "button", /Discover Molecules/
    assert_match "No molecules / compounds yet", response.body
  end

  test "molecules lists all molecules in a table grouped by chemical_class headers with themes" do
    europe = ChemicalClass.create!(name: "Alkaloids", description: "Naturally occurring basic nitrogen compounds.")
    asia = ChemicalClass.create!(name: "Terpenoids", description: "Diverse class of organic compounds derived from isoprene.")

    Molecule.create!(chemical_class: asia, name: "Caffeine", description: "Stimulant methylxanthine compound.", themes: [ "xanthine", "stimulant" ])
    Molecule.create!(chemical_class: europe, name: "Quinine", description: "Natural antimalarial alkaloid.", themes: [ "alkaloid", "antimalarial" ])
    Molecule.create!(chemical_class: europe, name: "Morphine", description: "Opioid analgesic alkaloid.", themes: [ "opioid", "analgesic" ])

    get molecules_url

    assert_response :success
    assert_select "table tbody", count: 2
    assert_select "table tbody tr th", /Alkaloids/
    assert_select "table tbody tr th", /Terpenoids/
    assert_operator response.body.index("Alkaloids"), :<, response.body.index("Terpenoids")
    assert_operator response.body.index("Morphine"), :<, response.body.index("Quinine")
    assert_match "Stimulant methylxanthine compound.", response.body
    assert_match "antimalarial", response.body
    assert_match "alkaloid", response.body
    assert_match "stimulant", response.body
  end

  test "functional_groups renders empty state, populate button, and top navbar link when no functional_groups exist" do
    get functional_groups_url

    assert_response :success
    assert_select "nav a[href=?]", functional_groups_path, text: "Atoms / Functional Groups"
    assert_select "h1", "Atoms / Functional Groups"
    assert_select "button", /Discover Atoms \/ Functional Groups/
    assert_match "No atoms / functional groups yet", response.body
  end

  test "functional_groups lists all functional_groups in a table grouped by molecule headers" do
    europe = ChemicalClass.create!(name: "Alkaloids", description: "Naturally occurring basic nitrogen compounds.")
    asia = ChemicalClass.create!(name: "Terpenoids", description: "Diverse class of organic compounds derived from isoprene.")

    quinine = Molecule.create!(chemical_class: europe, name: "Quinine", description: "Antimalarial cinchona alkaloid.")
    caffeine = Molecule.create!(chemical_class: asia, name: "Caffeine", description: "Methylxanthine stimulant.")

    FunctionalGroup.create!(molecule: quinine, name: "Quinoline Ring", description: "Aromatic nitrogen heterocycle.", themes: [ "heterocycle", "aromatic" ])
    FunctionalGroup.create!(molecule: quinine, name: "Quinuclidine", description: "Bicyclic tertiary amine cage.", themes: [ "amine", "bicyclic" ])
    FunctionalGroup.create!(molecule: caffeine, name: "Purine Dione Core", description: "Imidazopyrimidine dione bicyclic core.", themes: [ "purine", "dione" ])

    get functional_groups_url

    assert_response :success
    assert_select "table tbody", count: 2
    assert_select "table tbody tr th", /Caffeine/
    assert_select "table tbody tr th", /Quinine/
    assert_match "Quinoline Ring", response.body
    assert_match "Quinuclidine", response.body
    assert_match "Purine Dione Core", response.body
    assert_match "Bicyclic tertiary amine cage.", response.body
  end
end
