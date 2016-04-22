class CreatePollAnswers < ActiveRecord::Migration
  def change
    create_table :poll_answers do |t|
      t.integer :user_id, :null => false
      t.integer :issue_id, :null => false
      t.integer :poll_id, :null => false
      t.integer :answer_id
      t.string :answer_open
      
      t.timestamps
    end
  end
end
