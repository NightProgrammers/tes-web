require_relative 'spec_helper'
require_relative '../lib/env_manager'

describe Tes::EnvManager do
  subject { Tes::EnvManager.new 'test.yml'}
  describe :request_env do
    before(:each) do
      subject.clear
      # nodes and cluster
      nodes = '1.1.1.1'..'1.1.1.3'
      n_ids = nodes.map do |n|
        subject.add_res(type: 'node',
                        cfg: {
                            ip: n,
                            username: 'admin',
                            password: 'admin123'
                        })
      end
      subject.add_res(type: 'cluster', cfg: {
          member: n_ids,
          vs_enable: 1,
          master: n_ids.first
      })

      # storage
      subject.add_res(type: 'iscsi', cfg: {ip: '2.2.2.2', port: 3260})
      subject.add_res(type: 'iscsi', cfg: {ip: '2.2.2.2', port: 3260, chap_auth_enable: 1, chap_name: 'iscsi2', chap_sec_key: 123456})
      subject.add_res(type: 'iscsi', cfg: {ip: '2.2.2.2', port: 3260, chap_auth_enable: 1, chap_name: 'iscsi2', chap_sec_key: 123456, chap2_auth_enable: 1, chap2_name: 'iscsi2', chap2_sec_key: 123456})
      subject.add_res(type: 'nfs', cfg: {ip: '200.200.165.46', path: '/mnt/J1'})
      subject.add_res(type: 'nfs', cfg: {ip: '200.200.165.47', path: '/mnt/J1'})
      subject.add_res(type: 'samba', cfg: {ip: '200.200.0.3', path: '/临时文件夹', username: 'test', password: 'test'})
    end

    def check_lockes(lockes, expect_status)
      lockes.is_a?(Array) && lockes.each do |l|
        expect(subject.get_res(l)[:status]).to eq expect_status
      end
    end

    context 'request cluster' do
      it 'type=cluster,cfg.vs_enable=0' do
        ret = subject.request_env('wuhuizuo', 'type=cluster,cfg.vs_enable=0')
        expect(ret[:res]).to be_empty
        expect(ret[:lockes]).to be_empty
      end

      it 'type=cluster,cfg.vs_enable=1' do
        ret = subject.request_env('wuhuizuo', 'type=cluster,cfg.vs_enable=1')
        check_lockes(ret[:lockes], Tes::EnvManager::RES_STATUS[:locked])
        expect(ret[:res]).to be_a_kind_of(Hash)
        expect(ret[:res].size).to eq 1
        expect(ret[:res].values.first).to include(type: 'cluster')
        expect(ret[:res].values.first[:cfg]).to include(vs_enable: 1)
      end
      it 'type=cluster,cfg.member.size=3' do
        ret = subject.request_env('wuhuizuo', 'type=cluster,cfg.member.size=3')
        check_lockes(ret[:lockes], Tes::EnvManager::RES_STATUS[:locked])

        expect(ret[:res]).to be_a_kind_of(Hash)
        expect(ret[:res].size).to eq 1
      end
      it 'type=cluster,cfg.vs_enable=1,cfg.member.size=4' do
        ret = subject.request_env('wuhuizuo', 'type=cluster,cfg.vs_enable=1,cfg.member.size=4')
        expect(ret[:res]).to be_empty
        expect(ret[:lockes]).to be_empty
      end
      it '[*1]:type=cluster,cfg.member.size=3;[&1].cfg.member]' do
        ret = subject.request_env('wuhuizuo', "[*1]:type=cluster,cfg.member.size=3\n[&1].cfg.member")
        expect(ret[:lockes].size).to eq 4
        check_lockes(ret[:lockes], Tes::EnvManager::RES_STATUS[:locked])

        expect(ret[:res]).to be_a_kind_of(Hash)
        expect(ret[:res].size).to eq 4
      end

      it 'share_request' do
        ret1 = subject.request_env('wuhuizuo1', "$|*1:type=cluster,cfg.member.size=3\n&1.cfg.member")
        expect(ret1[:lockes].size).to eq 4
        check_lockes(ret1[:lockes], Tes::EnvManager::RES_STATUS[:using])
        expect(ret1[:res]).to be_a_kind_of(Hash)
        expect(ret1[:res].size).to eq 4

        ret2 = subject.request_env('wuhuizuo1', "$|*1:type=cluster,cfg.member.size=3\n&1.cfg.member")
        expect(ret2[:lockes].size).to eq 4
        check_lockes(ret2[:lockes], Tes::EnvManager::RES_STATUS[:using])
        expect(ret2[:res]).to be_a_kind_of(Hash)
        expect(ret2[:res].size).to eq 4
      end
    end
  end
end