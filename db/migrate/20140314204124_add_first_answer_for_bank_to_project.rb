class AddFirstAnswerForBankToProject < ActiveRecord::Migration
  def self.up
    add_column :projects, :first_answer_for_bank, :boolean
  end

  def self.down
    remove_column :projects, :first_answer_for_bank
  end
end
