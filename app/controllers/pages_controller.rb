# frozen_string_literal: true

class PagesController < ApplicationController
  def home
    @chemical_classes = ChemicalClass.ordered
  end

  def molecules
    @chemical_class_groups = Molecule.grouped_by_chemical_class
    @total_molecules_count = Molecule.count
    @chemical_classes_count = ChemicalClass.count
  end

  def functional_groups
    @molecule_groups = FunctionalGroup.grouped_by_molecule
    @total_functional_groups_count = FunctionalGroup.count
    @molecules_count = Molecule.count
  end
end
