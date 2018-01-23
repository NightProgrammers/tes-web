ENV['RACK_ENV'] ||= 'development'

require 'bundler'
Bundler.require :default, ENV['RACK_ENV'].to_sym

require_relative 'lib/env_manager'
require 'logger'
require 'json'
require 'sinatra/base'
require 'sinatra/json'

module Tes
  class App < Sinatra::Base
    # 初始化
    @@domains = {}

    def self.add_domain(name)
      if @@domains[name]
        false
      else
        config_file = File.join(__dir__, 'conf', 'domains', name, 'resource.yml')
        server = EnvManager.new config_file
        @@domains.merge!(name => server)
        true
      end
    end

    set :logging, true
    set :show_exceptions, :after_handler

    configure :production do
      # set :clean_trace, true
      # set :dump_errors, false
      Dir.mkdir('logs') unless File.exist?('logs')

      $logger = Logger.new('logs/common.log', 'weekly')
      $logger.level = Logger::WARN

      # Spit stdout and stderr to a file during production
      # in case something goes wrong
      $stdout.reopen('logs/output.log', 'w')
      $stdout.sync = true
      $stderr.reopen($stdout)

      # 初始化配置
      Dir.glob("#{__dir__}/conf/domains/*/resource.yml").each do |f|
        add_domain File.basename(File.dirname(f))
      end
    end

    configure :development do
      $logger = Logger.new(STDOUT)
    end

    set :root, __dir__
    set :public_folder, File.join(__dir__, 'client')

    def return_error(e)
      status 500
      json success: false, error: {message: e.message, detail: e.backtrace.join("\n")}
    end

    def deal_block(&block)
      block.call
    rescue RuntimeError => e
      return_error e
    end

    def get_domain(domain)
      domain_server = @@domains[domain]
      if domain_server
        block_given? ? yield(domain_server) : domain_server
      else
        status 500
        json success: false, error: {message: "No domain:#{domain} served!"}
      end
    end

    error RuntimeError do
      e = env['sinatra.error']
      $logger.error e.message
      json success: false, error: {message: e.message, detail: e.backtrace.join("\n")}
    end

    get '/' do
      erb :index
    end

    get '/domains' do
      json(success: true, data: @@domains.keys)
    end

    put '/domains' do
      domain_name = request.body.read.strip
      if domain_name =~ /.+/
        json(success: self.class.add_domain(domain_name))
      else
        json(success: false, error: {message: 'domain name should not be empty'})
      end
    end

    delete '/:domain' do |domain|
      deal_block do
        get_domain(domain) do |server|
          server.resources.each{|k,_v| server.destroy_res(k)}
          domain_dir = File.join(__dir__, 'conf', 'domains', domain)
          FileUtils.rm_rf(domain_dir)
          @@domains.delete(domain)
          json(success: true)
        end
      end
    end

    get '/:domain/res' do |domain|
      get_domain(domain) {|server| json(success: true, data: server.resources)}
    end

    put '/:domain/res' do |domain|
      get_domain(domain) do |server|
        res_cfg = JSON.parse(request.body.read, :symbolize_names => true)
        res_id = server.add_res(res_cfg)
        json(success: true, data: res_id)
      end
    end

    get '/:domain/res/:id' do |domain, res_id|
      get_domain(domain) do |server|
        res = server.get_res(res_id)
        json(success: true, data: res)
      end
    end

    post '/:domain/res/:id' do |domain, res_id|
      deal_block do
        get_domain(domain) do |server|
          detail = JSON.parse(request.body.read, :symbolize_names => true)
          server.update_res(res_id, detail)
          json success: true
        end
      end
    end

    delete '/:domain/res/:id' do |domain, res_id|
      deal_block do
        get_domain(domain) do |server|
          res = server.destroy_res(res_id)
          json(success: res ? true : false, data: res)
        end
      end
    end

    post '/:domain/res/:id/lock' do |domain, res_id|
      user, lock = params[:user], params[:lock]
      lock = (lock.to_i == 1 ? true : false)
      get_domain(domain) do |server|
        ret = server.lock_res(res_id, user, lock)
        json(success: ret ? true : false, data: ret)
      end
    end

    post '/:domain/res/:id/release' do |domain, res_id|
      user = params[:user]
      get_domain(domain) do |server|
        server.release_res(res_id, user)
        json(success: true)
      end
    end

    post '/:domain/env/lock' do |domain|
      to_locks = JSON.parse(request.body.read, :symbolize_names => true)
      user, list, lock = to_locks[:user], to_locks[:list], to_locks[:lock]
      lock = (lock.to_i == 1 ? true : false)
      get_domain(domain) do |server|
        got_list = server.lock_res_list(user, Hash[list.map {|e| [e, lock]}])
        json(success: got_list ? true : false, data: got_list)
      end
    end

    post '/:domain/env' do |domain|
      data = JSON.parse(request.body.read, :symbolize_names => true)
      ask, user = data[:ask], data[:user]
      get_domain(domain) do |server|
        ret = server.request_env(user, ask)
        ret.merge!(domain: domain)
        if ret[:res].empty?
          json(success: false, data: ret)
        else
          json(success: true, data: ret)
        end
      end
    end
  end
end