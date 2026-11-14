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
    ChemicalClass.create!(name: "Alkaloids", description: "Alkaloidsan chemical_class.")
    ChemicalClass.create!(name: "Terpenoids", description: "Terpenoidsn chemical_class.")

    get root_url

    assert_response :success
    assert_select "article h2", count: 2
    assert_operator response.body.index("Alkaloids"), :<, response.body.index("Terpenoids")
    assert_match "Alkaloidsan chemical_class.", response.body
    assert_match "Terpenoidsn chemical_class.", response.body
  end

  test "molecules renders empty state and populate button when no molecules exist" do
    get molecules_url

    assert_response :success
    assert_select "h1", "Molecules / Compounds"
    assert_select "button", /Discover Molecules/
    assert_match "No molecules / compounds yet", response.body
  end

  test "molecules lists all molecules in a table grouped by chemical_class headers with themes" do
    europe = ChemicalClass.create!(name: "Alkaloids", description: "Alkaloidsan chemical_class.")
    asia = ChemicalClass.create!(name: "Terpenoids", description: "Terpenoidsn chemical_class.")

    Molecule.create!(chemical_class: asia, name: "Caffeine", description: "East Terpenoidsn state.", themes: [ "island", "tech" ])
    Molecule.create!(chemical_class: europe, name: "Quinine", description: "Western Alkaloidsan republic.", themes: [ "republic", "nuclear" ])
    Molecule.create!(chemical_class: europe, name: "Morphine", description: "Central Alkaloidsan republic.", themes: [ "federal", "manufacturing" ])

    get molecules_url

    assert_response :success
    assert_select "table tbody", count: 2
    assert_select "table tbody tr th", /Alkaloids/
    assert_select "table tbody tr th", /Terpenoids/
    assert_operator response.body.index("Alkaloids"), :<, response.body.index("Terpenoids")
    assert_operator response.body.index("Morphine"), :<, response.body.index("Quinine")
    assert_match "East Terpenoidsn state.", response.body
    assert_match "nuclear", response.body
    assert_match "republic", response.body
    assert_match "tech", response.body
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
    europe = ChemicalClass.create!(name: "Alkaloids", description: "Alkaloidsan chemical_class.")
    asia = ChemicalClass.create!(name: "Terpenoids", description: "Terpenoidsn chemical_class.")

    france = Molecule.create!(chemical_class: europe, name: "Quinine", description: "Western Alkaloids.")
    japan = Molecule.create!(chemical_class: asia, name: "Caffeine", description: "East Terpenoids.")

    FunctionalGroup.create!(molecule: france, name: "Quinoline Ring", description: "Aromatic nitrogen heterocycle.", themes: [ "capital", "diplomacy" ])
    FunctionalGroup.create!(molecule: france, name: "Marseille", description: "Mediterranean port gateway.", themes: [ "port" ])
    FunctionalGroup.create!(molecule: japan, name: "Purine Dione Core", description: "Megafunctional_group capital.", themes: [ "capital", "finance" ])

    get functional_groups_url

    assert_response :success
    assert_select "table tbody", count: 2
    assert_select "table tbody tr th", /Caffeine/
    assert_select "table tbody tr th", /Quinine/
    assert_match "Quinoline Ring", response.body
    assert_match "Marseille", response.body
    assert_match "Purine Dione Core", response.body
    assert_match "Mediterranean port gateway.", response.body
  end
end
