class AddRedmineToIssue < ActiveRecord::Migration
  def self.up
    add_column :issues, :is_from_redmine, :boolean
  end

  def self.down
    remove_column :issues, :is_from_redmine
  end
end
