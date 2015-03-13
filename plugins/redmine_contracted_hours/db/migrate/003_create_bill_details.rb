class CreateBillDetails < ActiveRecord::Migration
  def change
    create_table :bill_details do |t|
      t.integer :issue_id
      t.integer :tracker_id
      t.integer :status_id
      t.float :estimated_hours
      t.float :time_entries
      t.belongs_to :bill
    end
    add_index :bill_details, :bill_id
  end
end
