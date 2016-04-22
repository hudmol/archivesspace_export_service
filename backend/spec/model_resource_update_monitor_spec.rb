require 'spec_helper'

describe 'Resource Update Monitor model' do

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
    past = Time.now.to_i - 1
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

end
