class AddNotaPublicaObligatoriaToProject < ActiveRecord::Migration
  def self.up
    add_column :projects, :nota_publica_obligatoria_estado_cliente, :boolean
  end

  def self.down
    remove_column :projects, :nota_publica_obligatoria_estado_cliente
  end
end
