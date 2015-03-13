class CreateBills < ActiveRecord::Migration
  def change
    create_table :bills do |t|
      t.integer :ch_id
      t.timestamp :date
      t.float :total_hours
    end
  end
end
