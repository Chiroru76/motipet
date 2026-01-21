class AddLocationToTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :tasks, :location_address, :string
    add_column :tasks, :latitude, :float
    add_column :tasks, :longitude, :float
    add_column :tasks, :place_id, :string
    add_column :tasks, :location_enabled, :boolean
  end
end
