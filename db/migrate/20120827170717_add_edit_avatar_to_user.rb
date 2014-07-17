class AddEditAvatarToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :edit_avatar, :boolean
  end

  def self.down
    remove_column :users, :edit_avatar
  end
end
