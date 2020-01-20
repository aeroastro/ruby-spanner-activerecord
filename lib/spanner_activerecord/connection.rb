require "google/cloud/spanner"
require "spanner_client_ext"
require "spanner_activerecord/information_schema"

module SpannerActiverecord
  class Connection
    attr_reader :spanner, :client

    def initialize \
        project_id,
        instance_id,
        database_id,
        credentials: nil,
        scope: nil,
        timeout: nil,
        client_config: nil,
        pool_config: nil,
        init_client: nil
      @instance_id = instance_id
      @database_id = database_id
      @pool_config = (pool_config || {}).symbolize_keys
      @spanner = Google::Cloud.spanner \
        project_id,
        credentials,
        scope: scope,
        timeout: timeout,
        client_config: client_config&.symbolize_keys

      return unless init_client
      @client = @spanner.client @instance_id, @database_id, pool: @pool_config
    end

    def active?
      execute_query "SELECT 1"
      true
    rescue StandardError
      false
    end

    def disconnect!
      @client.close
    end

    def reset!
      @client.reset
    end

    def execute_query sql, params: nil, types: nil, single_use: nil
      @client.execute_query(
        sql, params: params, types: types, single_use: single_use
      ).rows
    end

    # @params [Array<String>, String] sql Single or list of statements
    def execute_ddl statements, operation_id: nil, wait_until_done: true
      job = database.update statements: statements, operation_id: operation_id
      job.wait_until_done! if wait_until_done
      raise Google::Cloud::Error.from_error job.error if job.error?
      job.done?
    end

    def create_database
      job = @spanner.create_database @instance_id, @database_id
      job.wait_until_done!
      raise Google::Cloud::Error.from_error job.error if job.error?
      job.database
    end

    def database
      @database ||= begin
        database = @spanner.database @instance_id, @database_id
        raise Google::Cloud::NotFoundError, @database_id unless database
        database
      end
    end

    def inspect
      "#{self.class}(#{@spanner.project_id}/#{@instance_id}/#{@database_id})"
    end
  end
end
