require 'hodel_3000_compliant_logger'
require 'oink/utils/hash_utils'
require 'oink/instrumentation'

module Oink
  class Middleware
    def initialize(app, options = {})
      @app = app

      @logger = options[:logger] ||
                Hodel3000CompliantLogger.new('log/oink.log')

      @instruments = if options[:instruments]
                       Array(options[:instruments])
                     else
                       %i[memory activerecord]
                     end

      Oink.extend_active_record! if @instruments.include?(:activerecord)
    end

    def call(env)
      status, headers, body = @app.call(env)

      log_routing(env)
      log_memory
      log_activerecord
      log_completed

      [status, headers, body]
    end

    def log_completed
      @logger.info('Oink Log Entry Complete')
    end

    def log_routing(env)
      @logger.info("Oink Action: #{routing_info_string(env)}")
    end

    def log_memory
      return unless @instruments.include?(:memory)

      memory = Oink::Instrumentation::MemorySnapshot.memory
      @logger.info("Memory usage: #{memory} | PID: #{$$}")
    end

    def log_activerecord
      return unless @instruments.include?(:activerecord)

      hash    = ActiveRecord::Base.instantiated_hash
      objects = ActiveRecord::Base.total_objects_instantiated

      sorted_list = ["Total: #{objects}"] +
                    Oink::HashUtils.to_sorted_array(hash)

      @logger.info("Instantiation Breakdown: #{sorted_list.join(' | ')}")

      reset_objects_instantiated
    end

    private

    def routing_info_string(env)
      rails_routing_info(env) || raw_routing_info(env) || 'Unknown'
    end

    def rails_routing_info(env)
      info = rails3_routing_info(env) || rails2_routing_info(env)

      return unless info

      "#{info['controller']}##{info['action']}"
    end

    def rails3_routing_info(env)
      env['action_dispatch.request.parameters']
    end

    def rails2_routing_info(env)
      env['action_controller.request.path_parameters']
    end

    def raw_routing_info(env)
      env['PATH_INFO']
    end

    def reset_objects_instantiated
      ActiveRecord::Base.reset_instance_type_count
    end
  end
end
