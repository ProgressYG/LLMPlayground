class CreateResults < ActiveRecord::Migration[8.0]
  def change
    create_table :results do |t|
      t.references :execution, null: false, foreign_key: true
      t.integer :iteration_number
      t.text :response_text
      t.jsonb :tokens_used
      t.integer :response_time_ms
      t.string :status
      t.text :error_message

      t.timestamps
    end
  end
end
