class CreateTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :templates do |t|
      t.string :name
      t.text :description
      t.text :system_prompt
      t.text :user_prompt
      t.jsonb :default_parameters

      t.timestamps
    end
  end
end
