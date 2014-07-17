class AddAsignadoAObligatorioToProject < ActiveRecord::Migration
  def self.up
    add_column :projects, :asignado_a_obligatorio, :boolean
  end

  def self.down
    remove_column :projects, :asignado_a_obligatorio
  end
end
