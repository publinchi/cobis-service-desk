class CreateAnswers < ActiveRecord::Migration
  def change
    create_table :answers do |t|
      t.string :name, :null => false
      t.integer :poll_id, :null => false
    end
  end
end
