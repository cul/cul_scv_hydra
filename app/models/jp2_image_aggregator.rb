require "active-fedora"
require "hydra"
class JP2ImageAggregator < ::ActiveFedora::Base
  extend ActiveModel::Callbacks
  include ::ActiveFedora::Relationships
  include ::Hydra::ModelMethods
  include Cul::Scv::Hydra::ActiveFedora::Model
  include Cul::Scv::Hydra::ActiveFedora::Model::Aggregator

  has_datastream :name => "SOURCE", :type=>::ActiveFedora::Datastream, :mimeType=>"image/jp2", :controlGroup=>'E'

  define_model_callbacks :create
  after_create :aggregator!

  alias :file_objects :resources
  def create
    run_callbacks :create do
      super
    end
  end
  def route_as
    "zoomingimage"
  end
  def index_type_label
    "PART"
  end
  def to_solr(solr_doc = Hash.new, opts={})
    solr_doc = super
    source = self.datastreams["SOURCE"]
    source.profile
    if source.controlGroup == 'E'
      solr_doc["rft_id"] = source.dsLocation
    else
      rc = ActiveFedora::RubydoraConnection.instance.connection
      url = rc.config["url"]
      uri = URI::parse(url)
      url = "#{uri.scheme}://#{uri.host}:#{uri.port}/fedora/objects/#{pid}/datastreams/#{SOURCE}/content"
      solr_doc["rft_id"] = url
    end
    solr_doc
  end
end