require_relative 'db_connection'
require 'active_support/inflector'
# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject
  def self.columns
    @columns || (
    cols = DBConnection.execute2(<<-SQL)
    SELECT
      *
    FROM
      #{self.table_name}
    SQL

    @columns = cols.first.map!(&:to_sym))
  end

  def self.finalize!
    columns.each do |column|
      define_method("#{column}") {self.attributes[column]}
      define_method("#{column}=") {|value| self.attributes[column] = value}
    end
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    @table_name || "#{self}".tableize
  end

  def self.all
    all = DBConnection.execute(<<-SQL)
      SELECT
        *
      FROM
        #{table_name}
    SQL
    self.parse_all(all)
  end

  def self.parse_all(results)
    obj_arr = []
    parameters = Hash.new(0)
    results.each do |object|
      obj_arr <<  self.new(object)
    end
    obj_arr
  end

  def self.find(id)
    found = DBConnection.execute(<<-SQL, id)
      SELECT
        *
      FROM
        #{table_name}
      WHERE
        id = ?
    SQL
    self.parse_all(found).first
  end

  def initialize(params = {})
    params.each do |k, v|
      attr_name = k.to_sym
      unless self.class.columns.include?(attr_name)
        raise Exception.new("unknown attribute '#{k}'")
      end
      self.send("#{attr_name}=", v)
    end

  end

  def attributes
    @attributes || @attributes = Hash.new(0)
  end

  def attribute_values
     self.class.columns.map { |attr| self.send(attr) }
  end

  def insert
    col_names = self.class.columns.join(", ")
    q_marks = (["?"] * self.class.columns.length).join(", ")
    vals = self.attribute_values
    DBConnection.execute(<<-SQL, *vals)
      INSERT INTO
        #{self.class.table_name} (#{col_names})
      VALUES
        (#{q_marks})
    SQL
     self.id = DBConnection.last_insert_row_id

  end

  def update
    col_names = self.class.columns.map {|attr| "#{attr} = ?"}.join(", ")
    vals = self.attribute_values
    DBConnection.execute(<<-SQL, *vals, self.id)
    UPDATE
      #{self.class.table_name}
    SET
      #{col_names}
    WHERE
      id = ?
    SQL

  end

  def save
    if self.id.nil? || self.id == 0
      insert
    else
      update
    end
  end
end
