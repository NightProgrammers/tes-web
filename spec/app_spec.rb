require_relative 'spec_helper'

describe Tes::App do
  before(:all) { FileUtils.rm_rf(File.join(__dir__, '..', 'conf', 'domains')) }
  let(:domain) do
    name = 'zwh'
    put '/domains', name
    name
  end
  let(:node_res) do
    res = {type: 'cluster', cfg: {ip: '1.1.1.1', member: ['1.1.1.1'], username: 'admin', password: 'admin'}}
    put "/#{domain}/res", res.to_json
    expect(last_response.status).to eq 200
    ret = get_res_hash
    ret && ret[:success] && ret[:data]
  end
  let(:node_res2) do
    res = {type: 'cluster', cfg: {ip: '1.1.1.2', member: ['1.1.1.2'], username: 'admin', password: 'admin'}}
    put "/#{domain}/res", res.to_json
    expect(last_response.status).to eq 200
    ret = get_res_hash
    ret && ret[:success] && ret[:data]
  end

  def get_res_hash
    JSON.parse(last_response.body, :symbolize_names => true) rescue nil
  end
  
  context 'DELETE /{domain}' do
    let(:exists_domain) do
      name = 'test_delete'
      put '/domains', name
      name
    end
    let(:res_in_exists_domain) do
      res = {type: 'xxx', cfg: {xxx: 'xxx'}}
      put "/#{exists_domain}/res", res.to_json
      expect(last_response.status).to eq 200
      ret = get_res_hash
      ret && ret[:success] && ret[:data]
    end
    
    it 'exists' do
      res_in_exists_domain
      
      delete "/#{exists_domain}"
      expect(last_response.status).to eq 200
      ret = get_res_hash
      ret && ret[:success]
    end
    it 'exists but some res is locked' do
      post "/#{exists_domain}/res/#{res_in_exists_domain}/lock", {lock: 1, user: 'wuhuizuo'}
      
      delete "/#{exists_domain}"
      ret = get_res_hash
      expect(last_response.status).to eq 500
      expect(ret[:error][:message]).to eq 'res to delete should not be occupied'
    end
    it 'not_exists' do
      delete '/not_exist_domain'
      expect(last_response.status).to eq 500
    end
  end

  it 'PUT /{domain}/res' do
    put "/#{domain}/res", {type: 'cluster', cfg: {ip: '1.1.1.1', member: ['1.1.1.1'], username: 'admin', password: 'admin'}}.to_json
    expect(last_response.status).to eq 200
    ret_data = get_res_hash
    expect(ret_data).to include(success: true)
    expect(ret_data).to include(:data)
    res_id = ret_data[:data]
    expect(res_id).to be_truthy
  end
  context 'POST /{domain}/res/:id/lock' do
    def common_check(res_id)
      expect(last_response.status).to eq 200
      ret = get_res_hash
      expect(ret).to eq({success: true, data: res_id})
      get "/#{domain}/res/#{node_res}"
      expect(last_response.status).to eq 200
      ret = get_res_hash
      yield ret[:data] if block_given?
    end

    it 'lock' do
      post "/#{domain}/res/#{node_res}/lock", {lock: 1, user: 'wuhuizuo'}
      common_check(node_res) do |ret|
        expect(ret[:status]).to eq Tes::EnvManager::RES_STATUS[:locked]
        expect(ret[:users]).to eq ['wuhuizuo']
      end
    end
    it 'share using' do
      post "/#{domain}/res/#{node_res}/lock", {user: 'wuhuizuo'}
      common_check(node_res) do |ret|
        expect(ret[:status]).to eq Tes::EnvManager::RES_STATUS[:using]
        expect(ret[:users]).to eq ['wuhuizuo']
      end
      post "/#{domain}/res/#{node_res}/lock", {user: 'wuhuizuo2'}
      common_check(node_res) do |ret|
        expect(ret[:status]).to eq Tes::EnvManager::RES_STATUS[:using]
        expect(ret[:users]).to eq ['wuhuizuo', 'wuhuizuo2']
      end
    end
    it 'no given lock user' do
      post "/#{domain}/res/#{node_res}/lock", {lock: 1}
      ret = JSON.parse(last_response.body, :symbolize_names => true)
      expect(ret).to eq({success: false, data: nil})
    end
    context 'lock the busy res' do
      it 'lock the res that locked by other' do
        post "/#{domain}/res/#{node_res}/lock", {lock: 1, user: 'wuhuizuo1'}
        post "/#{domain}/res/#{node_res}/lock", {lock: 1, user: 'wuhuizuo2'}
        expect(get_res_hash[:success]).not_to be_truthy
      end
      it 'lock the res that share using by other' do
        post "/#{domain}/res/#{node_res}/lock", {user: 'wuhuizuo1'}
        post "/#{domain}/res/#{node_res}/lock", {lock: 1, user: 'wuhuizuo2'}
        expect(get_res_hash[:success]).not_to be_truthy
      end
      it 'lock the res that locked by myself' do
        post "/#{domain}/res/#{node_res}/lock", {lock: 1, user: 'wuhuizuo'}
        post "/#{domain}/res/#{node_res}/lock", {lock: 1, user: 'wuhuizuo'}
        ret = get_res_hash
        expect(ret[:success]).to be_truthy
        expect(ret[:data]).to eq node_res
      end
      it 'lock the res that share using by myself' do
        post "/#{domain}/res/#{node_res}/lock", {user: 'wuhuizuo'}
        post "/#{domain}/res/#{node_res}/lock", {lock: 1, user: 'wuhuizuo'}
        ret = get_res_hash
        expect(ret[:success]).to be_truthy
        expect(ret[:data]).to eq node_res
      end
      it 'share using the locked res by myself' do
        post "/#{domain}/res/#{node_res}/lock", {lock: 1, user: 'wuhuizuo'}
        post "/#{domain}/res/#{node_res}/lock", {user: 'wuhuizuo'}
        ret = get_res_hash
        expect(ret[:success]).to be_truthy
        expect(ret[:data]).to eq node_res
        get "/#{domain}/res/#{node_res}"
        ret = get_res_hash
        expect(ret[:data][:status]).to eq Tes::EnvManager::RES_STATUS[:using]
      end
      it 'share using the locked res by other' do
        post "/#{domain}/res/#{node_res}/lock", {lock: 1, user: 'wuhuizuo'}
        post "/#{domain}/res/#{node_res}/lock", {user: 'wuhuizuo2'}
        ret = get_res_hash
        expect(ret[:success]).not_to be_truthy
      end
    end
  end
  context 'POST /{domain}/res/:id/release' do
    it 'release using-1' do
      post "/#{domain}/res/#{node_res}/lock", {user: 'wuhuizuo'}
      post "/#{domain}/res/#{node_res}/release", {user: 'wuhuizuo'}
      get "/#{domain}/res/#{node_res}"
      ret = get_res_hash
      expect(ret[:data][:status]).to eq Tes::EnvManager::RES_STATUS[:free]
      expect(ret[:data][:users]).to eq []
    end
    it 'release using-2' do
      post "/#{domain}/res/#{node_res}/lock", {user: 'wuhuizuo1'}
      post "/#{domain}/res/#{node_res}/lock", {user: 'wuhuizuo2'}
      post "/#{domain}/res/#{node_res}/release", {user: 'wuhuizuo1'}
      get "/#{domain}/res/#{node_res}"
      ret = get_res_hash
      expect(ret[:data][:status]).to eq Tes::EnvManager::RES_STATUS[:using]
      expect(ret[:data][:users]).to eq ['wuhuizuo2']

      post "/#{domain}/res/#{node_res}/release", {user: 'wuhuizuo2'}
      get "/#{domain}/res/#{node_res}"
      ret = get_res_hash
      expect(ret[:data][:status]).to eq Tes::EnvManager::RES_STATUS[:free]
      expect(ret[:data][:users]).to eq []
    end

    it 'release locked' do
      post "/#{domain}/res/#{node_res}/lock", {lock: 1, user: 'wuhuizuo'}
      post "/#{domain}/res/#{node_res}/release", {user: 'wuhuizuo'}
      get "/#{domain}/res/#{node_res}"
      ret = get_res_hash
      expect(ret[:data][:status]).to eq Tes::EnvManager::RES_STATUS[:free]
      expect(ret[:data][:users]).to eq []
    end
    it 'release free' do
      post "/#{domain}/res/#{node_res}/release", {user: 'wuhuizuo'}
      get "/#{domain}/res/#{node_res}"
      ret = get_res_hash
      expect(ret[:data][:status]).to eq Tes::EnvManager::RES_STATUS[:free]
    end
  end
  context 'DELETE /{domain}/res/:id' do
    it 'delete not exists one' do
      delete "/#{domain}/res/xxx"
      expect(last_response.status).to eq 500
    end
    it 'delete free one' do
      delete "/#{domain}/res/#{node_res}"
      expect(last_response.status).to eq 200
      ret = get_res_hash
      expect(ret).to include(success: true)
    end
    it 'delete locked one' do
      post "/#{domain}/res/#{node_res}/lock", {lock: 1, user: 'wuhuizuo'}
      delete "/#{domain}/res/#{node_res}"
      expect(last_response.status).to eq 500
    end
    it 'delete using one' do
      post "/#{domain}/res/#{node_res}/lock", {user: 'wuhuizuo'}
      delete "/#{domain}/res/#{node_res}"
      expect(last_response.status).to eq 500
    end
  end
  context 'POST /{domain}/env/lock' do
    it 'one' do
      params = {lock: 1, user: 'wuhuizuo', list: [node_res]}
      post "/#{domain}/env/lock", params.to_json
      expect(last_response.status).to eq 200
      ret = get_res_hash
      expect(ret[:success]).to eq true
      expect(ret[:data]).to contain_exactly(node_res)

      get "/#{domain}/res/#{node_res}"
      ret = get_res_hash
      expect(ret[:success]).to eq true
      ret = ret[:data]
      expect(ret[:status]).to eq Tes::EnvManager::RES_STATUS[:locked]
      expect(ret[:users]).to contain_exactly('wuhuizuo')
    end
    it 'many' do
      params = {lock: 1, user: 'wuhuizuo', list: [node_res, node_res2]}
      post "/#{domain}/env/lock", params.to_json
      expect(last_response.status).to eq 200
      ret = get_res_hash
      expect(ret[:success]).to eq true
      expect(ret[:data]).to contain_exactly(node_res, node_res2)

      [node_res, node_res2].each do |n|
        get "/#{domain}/res/#{n}"
        ret = get_res_hash
        expect(ret[:success]).to eq true
        ret = ret[:data]
        expect(ret[:status]).to eq Tes::EnvManager::RES_STATUS[:locked]
        expect(ret[:users]).to contain_exactly('wuhuizuo')
      end
    end
  end
end