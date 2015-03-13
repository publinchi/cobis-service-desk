class CreateContractedHours < ActiveRecord::Migration
  def change
    create_table :contracted_hours do |t|
      t.integer :project_id
      t.text :filters
      t.string :hours
      t.string :name
      t.integer :related_id
    end
  end
end
