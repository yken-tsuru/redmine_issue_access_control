class CreateIssueAccessRules < ActiveRecord::Migration[5.2]
  def change
    create_table :issue_access_rules do |t|
      t.references :issue, null: false, index: true
      t.references :principal, null: false, index: true

      t.timestamps
    end
    
    add_foreign_key :issue_access_rules, :issues
    add_foreign_key :issue_access_rules, :users, column: :principal_id
  end
end
