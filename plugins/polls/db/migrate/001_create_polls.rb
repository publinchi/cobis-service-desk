class CreatePolls < ActiveRecord::Migration
  def change
    create_table :polls do |t|
      t.string :question
      t.string :project_id,  :null => false
      t.boolean :open,  :null => false
      t.boolean :mandatory, :default => 'false' ,:null => false
    end
  end
end
