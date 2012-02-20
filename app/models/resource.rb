require "active-fedora"
require "cul_image_props"
require "hydra"
require "mime/types"
require "uri"
class Resource < ::ActiveFedora::Base
  extend ActiveModel::Callbacks
  include ::ActiveFedora::Relationships
  include ::Hydra::ModelMethods
  include Cul::Scv::Hydra::ActiveFedora::Model
  include Cul::Scv::Hydra::ActiveFedora::Model::Resource
  define_model_callbacks :create
  after_create :resource!

  alias :file_objects :resources
  def create
    run_callbacks :create do
      super
    end
  end
  def route_as
    "resource"
  end
  def index_type_label
    "FILE RESOURCE"
  end
  def to_solr(solr_doc = Hash.new, opts={})
    sdoc = super
    unless sdoc["extent_s"] || self.datastreams["CONTENT"].nil?
      sdoc["extent_s"] = [self.datastreams["CONTENT"].size]
    end
    sdoc
  end
  def set_title_and_label(new_title, opts={})
      if opts[:only_if_blank]
        if self.label.nil? || self.label.empty?
          self.label = new_title
          self.set_title( new_title )
        end
      else
        self.label = new_title
        set_title( new_title )
      end
    end

    # Set the title and label on the current object
    #
    # @param [String] new_title
    # @param [Hash] opts (optional) hash of configuration options
    def set_title(new_title, opts={})
      if has_desc? 
        desc_metadata_ds = self.datastreams["descMetadata"]
        if desc_metadata_ds.respond_to?(:title_values)
          desc_metadata_ds.title_values = new_title
        else
          desc_metadata_ds.title = new_title
        end
      end
    end
end
