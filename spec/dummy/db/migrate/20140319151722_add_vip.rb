class AddVip < ActiveRecord::Migration
  def change
    add_column :the_models, :vip, :string, default: "Some restricted info"
  end
end
