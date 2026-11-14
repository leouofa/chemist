# frozen_string_literal: true

class CreateMolecules < ActiveRecord::Migration[8.1]
  def change
    create_table :molecules do |t|
      t.references :chemical_class, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description, null: false
      t.jsonb :themes, default: [], null: false

      t.timestamps
    end

    add_index :molecules, "chemical_class_id, lower((name)::text)", name: "index_molecules_on_chemical_class_id_and_lower_name", unique: true
  end
end
