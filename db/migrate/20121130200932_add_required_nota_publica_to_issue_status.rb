class AddRequiredNotaPublicaToIssueStatus < ActiveRecord::Migration
  def self.up
    add_column :issue_statuses, :is_required_nota_publica_obligatoria, :boolean
  end

  def self.down
    remove_column :issue_statuses, :is_required_nota_publica_obligatoria
  end
end
