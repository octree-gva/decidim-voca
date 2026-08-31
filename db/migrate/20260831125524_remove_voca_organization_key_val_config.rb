# frozen_string_literal: true
class RemoveVocaOrganizationKeyValConfig < ActiveRecord::Migration[8.1]
  def change
    # Limpeza segura dos dados antes de remover a tabela.
    # Usamos 'if table_exists?' para evitar erros caso a migration seja rodada
    # em um banco onde a tabela já foi removida manualmente.
    if table_exists?(:voca_organization_key_val_configs)
      # Em tabelas muito grandes, considere fazer isso em batches fora da migration
      # ou aceitar que isso pode travar a tabela por um momento.
      execute "DELETE FROM voca_organization_key_val_configs"
    end

    # No Rails 8, não é estritamente necessário redeclarar as colunas no drop_table
    # dentro de um bloco 'change' para que o rollback funcione, pois o Rails
    # usa o histórico de schema. Porém, manter a estrutura clara é uma boa prática.
    drop_table :voca_organization_key_val_configs do |t|
      t.references :decidim_organization, null: false, foreign_key: true, index: { name: "voca_organization_key_val_configs_constraint_organization" }
      t.string :key, null: false
      t.string :value, null: false
      t.timestamps
    end
  end
end
