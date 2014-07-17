class AddIngresoToCustomField < ActiveRecord::Migration
  def self.up
    add_column :custom_fields, :ingreso, :boolean
  end

  def self.down
    remove_column :custom_fields, :ingreso
  end
end
