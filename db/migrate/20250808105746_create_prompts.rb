class CreatePrompts < ActiveRecord::Migration[8.0]
  def change
    create_table :prompts do |t|
      t.text :system_prompt
      t.text :user_prompt
      t.jsonb :parameters
      t.string :selected_model

      t.timestamps
    end
  end
end
