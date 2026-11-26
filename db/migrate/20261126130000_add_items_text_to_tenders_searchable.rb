# Lets searches match the descriptions of a tender's items. `items_text` holds them
# (written by Tenders::FetchDetails) and `searchable` now indexes it too, with weight D so
# matches in the object, additional info, agency or unit (weight A) rank higher.
#
# Same rules as FoldAccentsInTendersSearchable: accents folded with translate(), and the
# generated column is dropped and added again (PostgreSQL 16 cannot change its expression).
class AddItemsTextToTendersSearchable < ActiveRecord::Migration[8.1]
  ACCENTED = "áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ"
  UNACCENTED = "aaaaaeeeeiiiiooooouuuucnAAAAAEEEEIIIIOOOOOUUUUCN"

  TENDER_TEXT = <<~SQL.squish
    coalesce(object_description, '') || ' ' ||
    coalesce(additional_info, '') || ' ' ||
    coalesce(agency_name, '') || ' ' ||
    coalesce(unit_name, '')
  SQL
  ITEMS_TEXT = "coalesce(items_text, '')"

  TENDER_VECTOR = "to_tsvector('portuguese', translate(#{TENDER_TEXT}, '#{ACCENTED}', '#{UNACCENTED}'))"
  ITEMS_VECTOR = "to_tsvector('portuguese', translate(#{ITEMS_TEXT}, '#{ACCENTED}', '#{UNACCENTED}'))"

  WITH_ITEMS_SQL = "setweight(#{TENDER_VECTOR}, 'A') || setweight(#{ITEMS_VECTOR}, 'D')"

  def up
    add_column :tenders, :items_text, :text
    rebuild_searchable(WITH_ITEMS_SQL)
  end

  def down
    rebuild_searchable(TENDER_VECTOR)
    remove_column :tenders, :items_text
  end

  private
    def rebuild_searchable(expression)
      remove_column :tenders, :searchable
      add_column :tenders, :searchable, :virtual, type: :tsvector, as: expression, stored: true
      add_index :tenders, :searchable, using: :gin
    end
end
