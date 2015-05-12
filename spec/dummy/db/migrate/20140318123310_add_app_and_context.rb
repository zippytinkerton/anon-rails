class AddAppAndContext < ActiveRecord::Migration

  def change
    add_column :the_models, :app, :string
    add_column :the_models, :context, :string
  end

end
