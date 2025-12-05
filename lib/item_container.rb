# lib/item_container.rb
# frozen_string_literal: true

module MyApplicationMotovilin
  module ItemContainer
    def self.included(base)
      base.extend ClassMethods
      base.include InstanceMethods
    end

    module ClassMethods
      def items_created_count
        @items_created_count ||= 0
      end

      def increment_items_created(count = 1)
        @items_created_count = items_created_count + count
      end

      def class_info
        {
          name: name,
          version: "1.0.0",
          items_created_count: items_created_count
        }
      end
    end

    module InstanceMethods
      attr_reader :items

      def add_item(item)
        @items << item
        self.class.increment_items_created
        MyApplicationMotovilin::LoggerManager.log_processed_file(
          "Item added to #{self.class.name}: #{item.inspect}"
        )
        item
      end

      def remove_item(item)
        removed = @items.delete(item)
        MyApplicationMotovilin::LoggerManager.log_processed_file(
          "Item removed from #{self.class.name}: #{removed.inspect}"
        )
        removed
      end

      def delete_items
        count = @items.size
        @items.clear
        MyApplicationMotovilin::LoggerManager.log_processed_file(
          "All items deleted from #{self.class.name} (#{count} total)"
        )
        count
      end

      def method_missing(method_name, *args, &block)
        if method_name == :show_all_items
          MyApplicationMotovilin::LoggerManager.log_processed_file(
            "show_all_items called on #{self.class.name} for #{@items.size} items"
          )
          @items.each { |i| puts i.info }
        else
          super
        end
      end

      def respond_to_missing?(method_name, include_private = false)
        method_name == :show_all_items || super
      end

      def generate_test_items(count = 5)
        count.times do
          item = MyApplicationMotovilin::Item.generate_fake
          add_item(item) if item
        end
        @items
      end
    end
  end
end
