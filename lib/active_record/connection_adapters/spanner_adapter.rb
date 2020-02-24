require "securerandom"
require "active_record/base"
require "active_record/connection_adapters/abstract_adapter"
require "active_record/connection_adapters/spanner/type_metadata"
require "active_record/connection_adapters/spanner/database_statements"
require "active_record/connection_adapters/spanner/schema_statements"
require "active_record/connection_adapters/spanner/schema_definitions"
require "arel/visitors/spanner"
require "spanner_activerecord/connection"


module ActiveRecord
  module ConnectionHandling # :nodoc:
    def spanner_connection config
      connection = SpannerActiverecord::Connection.new config
      connection.connect!
      ConnectionAdapters::SpannerAdapter.new connection, logger, nil, config
    rescue Google::Cloud::Error => error
      if error.instance_of? Google::Cloud::NotFoundError
        raise ActiveRecord::NoDatabaseError
      end
      raise error
    end
  end

  module ConnectionAdapters
    class SpannerAdapter < AbstractAdapter
      ADAPTER_NAME = "spanner".freeze
      NATIVE_DATABASE_TYPES = {
        primary_key:  "STRING(36)",
        string:       { name: "STRING", limit: "MAX" },
        text:         { name: "STRING", limit: "MAX" },
        integer:      { name: "INT64" },
        bigint:       { name: "INT64" },
        float:        { name: "FLOAT64" },
        decimal:      { name: "FLOAT64" },
        datetime:     { name: "TIMESTAMP" },
        time:         { name: "TIMESTAMP" },
        date:         { name: "DATE" },
        binary:       { name: "BYTES", limit: "MAX" },
        boolean:      { name: "BOOL" }
      }.freeze

      include Spanner::DatabaseStatements
      include Spanner::SchemaStatements

      def initialize connection, logger, connection_options, config
        config[:prepared_statements] = false
        super connection, logger, config
        @connection_options = connection_options
      end

      def max_identifier_length
        128
      end

      def native_database_types
        NATIVE_DATABASE_TYPES
      end

      # Database

      def self.database_exists? config
        connection = ActiveRecord::Base.spanner_connection config
        connection.disconnect!
        true
      rescue ActiveRecord::NoDatabaseError
        false
      end

      # Connection management

      def active?
        @connection.active?
      end

      def disconnect!
        super
        @connection.disconnect!
      end

      def reset!
        super
        @connection.reset!
      end
      alias reconnect! reset!

      # Supported features

      def supports_bulk_alter?
        true
      end

      def supports_common_table_expressions?
        true
      end

      def supports_explain?
        true
      end

      def supports_index_sort_order?
        true
      end

      def supports_indexes_in_create?
        true
      end

      def supports_insert_on_conflict?
        true
      end
      alias supports_insert_on_duplicate_skip? supports_insert_on_conflict?
      alias supports_insert_on_duplicate_update? supports_insert_on_conflict?
      alias supports_insert_conflict_target? supports_insert_on_conflict?

      def supports_insert_returning?
        true
      end

      def supports_multi_insert?
        true
      end

      def supports_optimizer_hints?
        true
      end

      def supports_primary_key?
        true
      end

      def prefetch_primary_key? _table_name = nil
        true
      end

      def next_sequence_value _sequence_name
        SecureRandom.uuid
      end

      def arel_visitor
        Arel::Visitors::Spanner.new self
      end

      # Information Schema

      def information_schema
        SpannerActiverecord::InformationSchema.new @connection
      end

      private

      def initialize_type_map m = type_map
        m.register_type "BOOL", Type::Boolean.new
        register_class_with_limit m, %r{^BYTES}i, Type::Binary
        m.register_type "DATE", Type::Date.new
        m.register_type "FLOAT64", Type::Float.new
        m.register_type "INT64", Type::Integer.new(limit: 8)
        register_class_with_limit m, %r{^STRING}i, Type::String
        m.register_type "TIMESTAMP", Type::DateTime.new

        # TODO: Array and Struct
      end
    end
  end
end
