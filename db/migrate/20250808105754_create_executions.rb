class CreateExecutions < ActiveRecord::Migration[8.0]
  def change
    create_table :executions do |t|
      t.references :prompt, null: false, foreign_key: true
      t.integer :iterations
      t.string :status
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end
  end
end
