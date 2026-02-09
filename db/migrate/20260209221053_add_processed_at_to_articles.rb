class AddProcessedAtToArticles < ActiveRecord::Migration[8.1]
  def change
    add_column :articles, :processed_at, :datetime
  end
end
