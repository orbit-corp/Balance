class AddTypeToWorkspaces < ActiveRecord::Migration[8.1]
  def change
    add_column :workspaces, :type, :integer, null: false, default: 0
  end
end
