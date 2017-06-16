require_relative 'db_connection'
require_relative '01_sql_object'

module Searchable
  def where(params)
    cols = []
    params.keys.each {|k| cols << "#{k} = ?"}
    cols = cols.join(" AND ")
    vals = params.values
    result = DBConnection.execute(<<-SQL, *vals)
      SELECT
        *
      FROM
        #{self.table_name}
      WHERE
        #{cols}
    SQL

    parse_all(result)
  end
end


class SQLObject
  extend Searchable
end
