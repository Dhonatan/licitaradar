# Rebuilds `tenders.searchable` with accents folded (á → a, ç → c, …) so a search for
# "agencia" finds "agência" and vice versa.
#
# `unaccent()` is not IMMUTABLE, so it cannot be used in a generated column, and custom
# functions or text search configurations are not kept in db/schema.rb. The built-in
# translate() is immutable and needs neither. Queries are folded with the same table
# (Tender.fold_accents), so both sides always agree.
#
# PostgreSQL 16 cannot change the expression of a generated column, hence drop + add.
class FoldAccentsInTendersSearchable < ActiveRecord::Migration[8.1]
  ACCENTED = "áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ"
  UNACCENTED = "aaaaaeeeeiiiiooooouuuucnAAAAAEEEEIIIIOOOOOUUUUCN"

  SEARCHABLE_TEXT = <<~SQL.squish
    coalesce(object_description, '') || ' ' ||
    coalesce(additional_info, '') || ' ' ||
    coalesce(agency_name, '') || ' ' ||
    coalesce(unit_name, '')
  SQL

  FOLDED_SQL = "to_tsvector('portuguese', translate(#{SEARCHABLE_TEXT}, '#{ACCENTED}', '#{UNACCENTED}'))"
  ORIGINAL_SQL = "to_tsvector('portuguese', #{SEARCHABLE_TEXT})"

  def up
    rebuild_searchable(FOLDED_SQL)
  end

  def down
    rebuild_searchable(ORIGINAL_SQL)
  end

  private
    def rebuild_searchable(expression)
      remove_column :tenders, :searchable
      add_column :tenders, :searchable, :virtual, type: :tsvector, as: expression, stored: true
      add_index :tenders, :searchable, using: :gin
    end
end
