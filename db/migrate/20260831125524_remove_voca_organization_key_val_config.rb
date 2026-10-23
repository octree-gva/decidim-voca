# frozen_string_literal: true
class RemoveVocaOrganizationKeyValConfig < ActiveRecord::Migration[8.1]
  def change
    # Clear rows before dropping the table.
    # table_exists? keeps a rerun safe when the table was already dropped by hand.
    if table_exists?(:voca_organization_key_val_configs)
      # A large table stays locked until this DELETE finishes. Batch it outside the migration if that matters.
      execute "DELETE FROM voca_organization_key_val_configs"
    end

    # Rails 8 can roll back drop_table from schema history without redeclared columns.
    # The block stays so the previous table shape is visible here.
    drop_table :voca_organization_key_val_configs do |t|
      t.references :decidim_organization, null: false, foreign_key: true, index: { name: "voca_organization_key_val_configs_constraint_organization" }
      t.string :key, null: false
      t.string :value, null: false
      t.timestamps
    end
  end
end
