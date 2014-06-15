module ActiveMock

class RecordNotFound < StandardError
end

class ReservedFieldError < StandardError
end

class IdError < StandardError
end

class FileTypeMismatchError < StandardError
end

class RejectedParams < Exception
end

class Base

  include DoNothingActiveRecordMethods
  extend ActiveMock::Queries
  include ActiveMock::Creators

  def self.inherited(subclass)
    ActiveMocker::LoadedMocks.add(subclass)
  end

  class << self

    def records
      @records ||= Records.new
    end

    private :records

    def exists?(record)
      records.exists?(record)
    end

    def insert(record)
      records.insert(record)
    end

    def count
      all.length
    end

    delegate :first, :last, :to => :all

    def delete(id)
      find(id).delete
    end

    def to_a
      @records
    end

    alias_method :destroy, :delete

    def delete_all(options=nil)
      return records.reset_all_records if options.nil?
      where(options).map { |r| r.delete }.count
    end

    alias_method :destroy_all, :delete_all

    def build_type(type)
      Virtus::Attribute.build(type)
    end

    public

    def clear_mock
      @model_class_methods, @model_instance_methods = nil, nil
      delete_all
    end

  end

  attr_reader :associations, :types, :attributes

  def initialize(attributes = {}, &block)
    setup_instance_variables
    set_properties_block(attributes, &block)
  end

  def setup_instance_variables
    {'@model_instance_methods' => self.class.send(:model_instance_methods),
        '@model_class_methods' => self.class.send(:model_class_methods),
               '@associations' => self.class.associations,
                 '@attributes' => self.class.attributes,
                      '@types' => self.class.types}.each do |var, value|
      instance_variable_set(var, value.dup)
    end
  end

  private :setup_instance_variables

  def set_properties_block(attributes = {}, &block)
    yield self if block_given?
    set_properties(attributes)
  end
  private :set_properties_block

  def update(attributes={})
    set_properties(attributes)
  end

  def set_properties(attributes={})
    attributes.each do |key, value|
      begin
        send "#{key}=", value
      rescue NoMethodError
        raise ActiveMock::RejectedParams, "{:#{key}=>#{value.inspect}} for #{self.class.name}"
      end
    end
  end

  private :set_properties

  def save(*args)
    unless self.class.exists?(self)
      self.class.send(:insert, self)
    end
    true
  end

  alias save! save

  def delete
    self.class.send(:records).delete(self)
    true
  end

  def [](key)
    attributes[key]
  end

  def []=(key, val)
    attributes[key] = val
  end

  def new_record?
    !self.class.send(:records, self)
  end

  def persisted?
    self.class.all.map(&:id).include?(id)
  end

  def to_hash
    attributes
  end

  def inspect
    ObjectInspect.new(self.class.name, attributes)
  end

  def hash
    attributes.hash
  end

  def ==(obj)
    return false if obj.nil?
    return hash == obj.attributes.hash if obj.respond_to?(:attributes)
    hash == obj.hash if obj.respond_to?(:hash)
  end

  module PropertiesGetterAndSetter

    def read_attribute(attr)
      @attributes[attr]
    end

    def write_attribute(attr, value)
      @attributes[attr] = types[attr].coerce(value)
    end

    def read_association(attr)
      @associations[attr]
    end

    def write_association(attr, value)
      @associations[attr] = value
    end

    protected :read_attribute, :write_attribute, :read_association, :write_association

  end

  include PropertiesGetterAndSetter

  module MockAbilities

    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def mock_instance_method(method, &block)
        model_instance_methods[method.to_s] = block
      end

      def mock_class_method(method, &block)
        model_class_methods[method.to_s] = block
      end

      def model_class_methods
        @model_class_methods ||= HashWithIndifferentAccess.new
      end

      def model_instance_methods
        @model_instance_methods ||= HashWithIndifferentAccess.new
      end

      private :model_class_methods, :model_instance_methods


      def is_implemented(val, method)
        raise "#{method} is not Implemented for Class: #{name}" if val == :not_implemented
      end

    end

    def mock_instance_method(method, &block)
      @model_instance_methods[method.to_s] = block
    end

    def model_instance_methods
      self.class.send(:model_instance_methods).merge(@model_instance_methods)
    end

    def model_class_methods
      self.class.send(:model_class_methods).merge(@model_class_methods)
    end

    private :model_class_methods, :model_instance_methods

  end

  include MockAbilities

end
end