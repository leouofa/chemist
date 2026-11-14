# frozen_string_literal: true

class CreateChemicalClasses < ActiveRecord::Migration[8.1]
  def change
    create_table :chemical_classes do |t|
      t.string :name, null: false
      t.text :description, null: false

      t.timestamps
    end

    add_index :chemical_classes, "lower((name)::text)", name: "index_chemical_classes_on_lower_name", unique: true
  end
end
