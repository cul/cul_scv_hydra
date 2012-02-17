require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'mediashelf/active_fedora_helper'

describe "StaticImageAggregator" do
  before(:all) do
    ingest("ldpd:ContentAggregator", fixture( File.join("FOXML", "content-cmodel.xml")), true)
    @parentobj = ingest("test:c_agg", fixture( File.join("FOXML", "content-aggregator.xml")), true)
    @parentobj.send :update_index
    ingest("ldpd:StaticImageAggregator", fixture( File.join("FOXML", "image-cmodel.xml")), true)
    @cmodel = ingest("ldpd:StaticImageAggregator", fixture( File.join("FOXML", "image-cmodel.xml")), true)
  end
  
  before(:each) do
    @foxml = fixture( File.join("FOXML", "static-image-aggregator.xml"))
    ingest("test:si_agg", fixture( File.join("FOXML", "static-image-aggregator.xml")), true)
    ingest("test:thumb_image", fixture( File.join("FOXML", "resource-thumb.xml")), true)
    ingest("test:screen_image", fixture( File.join("FOXML", "resource-screen.xml")), true)
    ingest("test:max_image", fixture( File.join("FOXML", "resource-max.xml")), true)
    @fixtureobj = StaticImageAggregator.load_instance( "test:si_agg")
    @fixtureobj.send :update_index
    Resource.load_instance("test:thumb_image").send :update_index
    Resource.load_instance("test:screen_image").send :update_index
    Resource.load_instance("test:max_image").send :update_index
  end
  
  after(:each) do
    @fixtureobj.delete
    ActiveFedora::Base.load_instance("test:thumb_image").delete
    ActiveFedora::Base.load_instance("test:screen_image").delete
    ActiveFedora::Base.load_instance("test:max_image").delete
  end

  after(:all) do
    ActiveFedora::Base.load_instance("test:c_agg").delete
    ActiveFedora::Base.load_instance("ldpd:StaticImageAggregator").delete
    ActiveFedora::Base.load_instance("ldpd:ContentAggregator").delete
  end

  it "should be detectable by ActiveFedora" do
    Kernel.const_get('StaticImageAggregator').is_a?(Class).should == true
    Module.const_get('StaticImageAggregator').is_a?(Class).should == true
    obj = ActiveFedora::Base.load_instance("test:si_agg")
    ActiveFedora::ContentModel.models_asserted_by(obj).each { |m_uri|
      m_class = ActiveFedora::ContentModel.uri_to_model_class(m_uri)
    }
    the_model = ActiveFedora::ContentModel.known_models_for( obj ).first
    the_model.should == StaticImageAggregator
  end

  it "should produce the correct CModel PID" do
    @fixtureobj.cmodel_pid(@fixtureobj.class).should == "ldpd:StaticImageAggregator"
  end

  describe "rightsMetadata" do
    it "should have a rightsMetadata datastream" do
      @fixtureobj.datastreams["rightsMetadata"].class.name.should == "Hydra::RightsMetadata"
    end
    it "should have a permissions method" do
      @fixtureobj.datastreams["rightsMetadata"].respond_to?(:permissions).should == true
    end
  end

  describe "DC" do
    it "should have a DC datastream" do
      @fixtureobj.datastreams["DC"].class.should == Cul::Scv::Hydra::Om::DCMetadata
    end

    it "should be able to edit and push new data to Fedora" do
      new_value = "new.test.id.value"
      ds = @fixtureobj.datastreams["DC"]
      ds.update_indexed_attributes({[:identifier] => new_value})
      ds.dirty?.should be_true
      @fixtureobj.save
      ds.dirty?.should be_false
      updated = StaticImageAggregator.load_instance(@fixtureobj.pid)
      found = false
      ds.find_by_terms(:identifier).each { |node|
        found ||= node.text == new_value
      }
      found.should be_true
      found = false
      updated.datastreams["DC"].find_by_terms(:identifier).each { |node|
        found ||= node.text == new_value
      }
      found.should be_true
    end
  end

  describe "aggregation functions" do

    it "should be able to find its members/parts" do
      @fixtureobj.parts.length.should == 2
    end

    it "should be able to add members/parts" do
      obj = ActiveFedora::Base.load_instance("test:thumb_image")
      @fixtureobj.add_member(obj)
      @fixtureobj.parts.length.should == 3
    end

    it "should be able to find its containers" do
      @fixtureobj.containers.length.should == 1
    end
  end
end