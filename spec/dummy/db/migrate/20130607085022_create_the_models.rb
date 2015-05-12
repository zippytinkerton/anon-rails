class CreateTheModels < ActiveRecord::Migration
  def change
    create_table :the_models do |t|
      t.string :name
      t.string :description
      t.integer :lock_version
      t.integer :created_by
      t.integer :updated_by
      t.float   :score

      t.timestamps
    end
    add_index :the_models, :name, unique: true
  end
end
