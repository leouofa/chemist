# frozen_string_literal: true

class CreateFunctionalGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :functional_groups do |t|
      t.references :molecule, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description, null: false
      t.jsonb :themes, default: [], null: false

      t.timestamps
    end

    add_index :functional_groups, "molecule_id, lower((name)::text)", name: "index_functional_groups_on_molecule_id_and_lower_name", unique: true
  end
end
