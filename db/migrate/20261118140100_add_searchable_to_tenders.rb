# The PNCP API ignores keyword filters, so search happens here: a stored generated
# column with a Portuguese tsvector over the descriptive fields, indexed with GIN.
class AddSearchableToTenders < ActiveRecord::Migration[8.1]
  SEARCHABLE_SQL = <<~SQL.squish
    to_tsvector('portuguese',
      coalesce(object_description, '') || ' ' ||
      coalesce(additional_info, '') || ' ' ||
      coalesce(agency_name, '') || ' ' ||
      coalesce(unit_name, ''))
  SQL

  def change
    add_column :tenders, :searchable, :virtual, type: :tsvector, as: SEARCHABLE_SQL, stored: true
    add_index :tenders, :searchable, using: :gin
  end
end
