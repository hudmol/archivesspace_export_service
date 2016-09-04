require 'spec_helper'

describe 'Resource Update Monitor model' do

  let (:past) { Time.now.to_i - 1 }
  let (:monitor) { ResourceUpdateMonitor.new }

  it "insists on a timestamp" do
    expect { monitor.updates_since }.to raise_error(ArgumentError)
    expect { monitor.updates_since("NOT AN INT") }.to raise_error(TypeError)
  end


  it "returns a useful hash" do
    hash = monitor.updates_since(1)
    hash['timestamp'].should eq(1)
    hash['adds'].should eq([])
    hash['removes'].should eq ([])
  end


  it "reports updated resources" do
    add = create_resource('publish' => true)
    remove = create_resource('publish' => false)
    hash = monitor.updates_since(past)
    hash['adds'][0]['id'].should eq(add[:id])
    hash['removes'][0].should eq(remove[:id])
  end


  it "ignores old updates" do
    add = create_resource('publish' => true)
    remove = create_resource('publish' => false)
    hash = monitor.updates_since(Time.now.to_i + 1)
    hash['adds'].should eq([])
    hash['removes'].should eq([])
  end


  it "reports unpublished resources as removes" do
    remove = create_resource('publish' => false)
    hash = monitor.updates_since(past)
    hash['removes'][0].should eq(remove[:id])
  end


  it "reports suppressed resources as removes" do
    remove = create_resource('suppressed' => true)
    hash = monitor.updates_since(past)
    hash['removes'][0].should eq(remove[:id])
  end


  it "reports deleted resources as removes" do
    resource = create_resource
    id = resource[:id]
    resource.delete
    hash = monitor.updates_since(past)
    hash['removes'][0].should eq(id)
  end


  it "can report updates for a repository" do
    res_in_this_repo = create_resource('publish' => true)
    res_in_other_repo = nil
    other_repo = make_test_repo("other_repo")
    RequestContext.open(:repo_id => other_repo) do
      res_in_other_repo = create_resource('publish' => true)
    end
    hash = monitor.updates_since(past)
    hash['adds'].length.should eq (2)
    monitor.repo_id(other_repo)
    hash = monitor.updates_since(past)
    hash['adds'].length.should eq (1)
  end


  it "can report updates for a particular resource by identifier" do
    res_with_id = create_resource('publish' => true, 'id_0' => 'aaa', 'id_1' => 'bbb')
    some_other_res = create_resource('publish' => true)
    yet_another_res = create_resource('publish' => true)
    monitor.identifier(['aaa', 'bbb', nil, nil].to_json)
    hash = monitor.updates_since(past)
    hash['adds'].length.should eq (1)
  end


  it "can report updates for a range of resource identifiers" do
    res1 = create_resource('publish' => true, 'id_0' => 'aaa', 'id_1' => 'bbb')
    res2 = create_resource('publish' => true, 'id_0' => 'aaa', 'id_1' => 'ccc')
    res3 = create_resource('publish' => true, 'id_0' => 'aaa', 'id_1' => 'ddd')
    res4 = create_resource('publish' => true, 'id_0' => 'bbb', 'id_1' => 'bbb')
    monitor.identifier(['aaa', 'bbb', nil, nil].to_json, ['aaa', 'ddd', nil, nil].to_json)
    monitor.updates_since(past)['adds'].length.should eq (3)
    monitor.identifier(['aaa', nil, nil, nil].to_json, ['aaa', nil, nil, nil].to_json)
    monitor.updates_since(past)['adds'].length.should eq (3)
    monitor.identifier(['aaa', nil, nil, nil].to_json, ['bbb', nil, nil, nil].to_json)
    monitor.updates_since(past)['adds'].length.should eq (4)
    monitor.identifier(['aaa', 'bbb', nil, nil].to_json, ['aaa', 'ccc', nil, nil].to_json)
    monitor.updates_since(past)['adds'].length.should eq (2)
    monitor.identifier(['aaa', 'bbb', nil, 'zzz'].to_json, ['bbb', 'ddd', nil, 'aaa'].to_json)
    monitor.updates_since(past)['adds'].length.should eq (0)
  end


  it "allows identifier part ranges to be specified high low" do
    res1 = create_resource('publish' => true, 'id_0' => 'aaa', 'id_1' => 'bbb')
    monitor.identifier(['aaa', 'ccc', nil, nil].to_json, ['aaa', 'aaa', nil, nil].to_json)
    monitor.updates_since(past)['adds'].length.should eq (1)
  end


  it "ignores an identifier part if either end of the range is nil" do
    res1 = create_resource('publish' => true, 'id_0' => 'aaa', 'id_1' => 'bbb')
    monitor.identifier(['aaa', 'zzz', nil, nil].to_json, ['aaa', nil, nil, nil].to_json)
    monitor.updates_since(past)['adds'].length.should eq (1)
  end

  describe "linked record updates" do

    let!(:resource) { create_resource('publish' => true, 'id_0' => 'linky', 'id_1' => 'resource') }
    let!(:subject) { create(:json_subject) }
    let!(:agent) { create(:json_agent_person) }
    let!(:digital_object) { create(:json_digital_object) }
    let!(:digital_object_component) {
      create(:json_digital_object_component,
             :digital_object => {'ref' => digital_object.uri})
    }

    let!(:archival_object) {
      create(:json_archival_object,
             :title => "linked archival object",
             :resource => {'ref' => resource.uri},
             :subjects => [{'ref' => subject.uri}],
             :instances => [build(:json_instance,
                                  :digital_object => {'ref' => digital_object.uri})],
             :linked_agents => [{'ref' => agent.uri, 'role' => 'creator'}])
    }

    let (:mtime) {
      # Space out each test with sleeps to make sure each test runs at least 1
      # second after the last one did something.
      sleep 1
      result = Time.now.to_i
      sleep 1
      result
    }

    it "reports updates for linked archival objects" do
      monitor.updates_since(mtime)['adds'].should be_empty
      archival_object.refetch
      archival_object.save
      monitor.updates_since(mtime)['adds'].should_not be_empty
    end

    it "reports updates for linked subjects" do
      monitor.updates_since(mtime)['adds'].should be_empty
      subject.refetch
      subject.save
      monitor.updates_since(mtime)['adds'].should_not be_empty
    end

    it "reports updates for linked agents" do
      monitor.updates_since(mtime)['adds'].should be_empty
      agent.refetch
      agent.save
      monitor.updates_since(mtime)['adds'].should_not be_empty
    end

    it "reports updates for linked digital objects" do
      monitor.updates_since(mtime)['adds'].should be_empty
      digital_object.refetch
      digital_object.save
      monitor.updates_since(mtime)['adds'].should_not be_empty
    end

    it "reports updates for linked digital object components" do
      monitor.updates_since(mtime)['adds'].should be_empty
      digital_object_component.refetch
      digital_object_component.save
      monitor.updates_since(mtime)['adds'].should_not be_empty
    end

  end

end
