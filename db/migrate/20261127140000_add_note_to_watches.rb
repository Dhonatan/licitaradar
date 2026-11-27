# A private plain-text note of the user about a watched tender.
class AddNoteToWatches < ActiveRecord::Migration[8.1]
  def change
    add_column :watches, :note, :text
  end
end
