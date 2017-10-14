require 'thread'
require 'yaml'
require 'securerandom'
require 'tes/request'

module Tes
  class EnvManager
    RES_STATUS = {free: 0, locked: 1, using: 2}
    attr_reader :resources

    def initialize(resource_file)
      @data_file = resource_file
      @semaphore = Mutex.new

      @resources = if File.exists?(@data_file)
                     YAML.load_file(@data_file) || {}
                   else
                     FileUtils.mkdir_p(File.dirname(@data_file))
                     {}
                   end
    end

    def clear
      synchronize do
        @resources.clear
      end
    end

    def get_status_map
      RES_STATUS
    end

    # @return [String,nil] res id if lock successfully else nil
    def lock_res(res_id, user, lock = true)
      assert_res(res_id)
      synchronize {|db| f_lock_res(db, res_id, user, lock)}
    end

    # @param [String] user what user to use to lock/share request resource
    # @param [Hash<String, true|false>] res_list
    # @return [Array<String>]
    def lock_res_list(user, res_list)
      res_list.each {|r, _lock| assert_res(r)}
      synchronize do |db|
        if res_list.all? {|id, lock| f_lock_res(db, id, user, lock)}
          res_list.keys
        else
          res_list.each_key {|id| f_release_res(db, id, user)}
          nil
        end
      end
    end

    def release_res(res_id, user)
      assert_res(res_id)
      synchronize {|db| f_release_res(db, res_id, user)}
    end

    def get_res(res_id)
      assert_res(res_id)
      synchronize {|db| db[res_id]}
    end

    def destroy_res(res_id)
      assert_res(res_id)
      res_state = resources[res_id][:status]
      if res_state == RES_STATUS[:using] or res_state == RES_STATUS[:locked]
        raise('res to delete should not be occupied')
      end

      synchronize {|db| db.delete(res_id) if db.key? res_id}
    end

    # @param [Hash] res_cfg
    # @return [String] new res id
    def add_res(res_cfg)
      res_id = SecureRandom.uuid
      synchronize {|db| db[res_id] = {:status => RES_STATUS[:free]}.merge(res_cfg)}
      res_id
    end

    def update_res(res_id, res_cfg)
      assert_res(res_id)
      synchronize {|db| db[res_id] = res_cfg}
    end


    # 申请配套资源
    # @param [String] profile_str 资源标签表达式
    # @return [Hash]
    def request_env(user, profile_str)
      raise('arg only support string') unless profile_str.is_a?(String)

      profile_lines = profile_str.split(/\s*;|\n\s*/)
      profile = Request::Profile.new(profile_lines)

      free_pool = resources.reject {|_k, res| res[:status] == RES_STATUS[:locked]}
      answers = profile.request(free_pool)

      if answers.size > 0
        if answers.all? {|answer| answer.is_a?(Array) ? (answer.size > 0) : answer}
          answers_flat_lock_map = (profile.data.zip answers).inject({}) do |t, (ask, answer)|
            if answer.is_a?(Array)
              t.merge(Hash[answer.flatten.map {|res| [res, ask.lock_type == :lock]}])
            else
              t.merge(answer => (ask.lock_type == :lock))
            end
          end
          if lock_res_list(user, answers_flat_lock_map)
            result = {res: Hash[answers_flat_lock_map.keys.map {|k| [k, resources[k]]}], lockes: answers_flat_lock_map.keys}
            return result
          end
        end
      end

      # 资源不能全部满足,返回空的东西
      {res: {}, lockes: []}
    end

    private
    # 根据表达式计算数据的值
    def data_expr(detail, exp)
      chains = exp.split('.')
      chains.keep_if {|k| k =~ /.+/}
      chains.inject(detail) {|t, p| t && t.send(p)}
    end

    def assert_res(res_id)
      raise("Error: no res found by id:#{res_id}") unless resources.key?(res_id)
    end

    def synchronize(&block)
      @semaphore.synchronize do
        h1 = @resources.hash
        ret = block.call(@resources)
        h2 = @resources.hash
        File.open(@data_file, 'w') {|f| f.write @resources.to_yaml} unless h1 == h2
        ret
      end
    end

    # @return [String, nil]
    def f_lock_res(db, res_id, user, lock)
      return nil unless res_id and user
      res = db[res_id]
      state_set = lock ? :locked : :using
      case res[:status]
        when RES_STATUS[:free]
          res[:users] ||= []
          res[:users].push(user).uniq!
          res[:status] = RES_STATUS[state_set]
        when RES_STATUS[:using]
          return nil if lock and not res[:users] == [user]
          res[:status] = RES_STATUS[state_set]
          res[:users].push(user).uniq!
        when RES_STATUS[:locked]
          return nil unless res[:users] == [user]
          res[:status] = RES_STATUS[state_set]
        else
          return nil
      end
      res_id
    end

    def f_release_res(db, res_id, user)
      res = db[res_id]
      case res[:status]
        when RES_STATUS[:using], RES_STATUS[:locked]
          res[:users].delete(user)
          res[:status] = RES_STATUS[:free] if res[:users].empty?
        else
          #nothing
      end
    end

  end
end