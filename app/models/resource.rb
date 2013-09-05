require "active-fedora"
require "cul_image_props"
require "mime/types"
require "uri"
class Resource < ::ActiveFedora::Base
  extend ActiveModel::Callbacks
  include ::ActiveFedora::Finders
  include ::ActiveFedora::DatastreamCollections
  include ::Hydra::ModelMethods
  include Cul::Scv::Hydra::ActiveFedora::Model::Common
  include Cul::Scv::Hydra::ActiveFedora::Model::Resource

  alias :file_objects :resources

  CUL_WIDTH = "http://purl.oclc.org/NET/CUL/RESOURCE/STILLIMAGE/BASIC/imageWidth"
  CUL_LENGTH = "http://purl.oclc.org/NET/CUL/RESOURCE/STILLIMAGE/BASIC/imageLength"
  FORMAT = "http://purl.org/dc/elements/1.1/format"
  MEMBER_OF = "http://purl.oclc.org/NET/CUL/memberOf"

  def route_as
    "resource"
  end

  def index_type_label
    "FILE RESOURCE"
  end

  def to_solr(solr_doc = Hash.new, opts={})
    super
    unless solr_doc["extent_ssi"] || self.datastreams["CONTENT"].nil?
      solr_doc["extent_ssi"] = [self.datastreams["CONTENT"].size]
    end
    solr_doc
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
    
    def thumbnail_info
      # do the triples indicate this is a thumb? fetch
      width = object_relations[CUL_WIDTH].first.to_i
      length = object_relations[CUL_LENGTH].first.to_i
      if width <= 251 && length <= 251
        mime = object_relations[FORMAT].first
        url = {:url=>"#{ActiveFedora.fedora_config[:url]}/objects/#{self.pid}/datastreams/CONTENT/content", :mime=>mime}
      else
        if object_relations[MEMBER_OF].blank?
          return {:url=>image_url("cul_scv_hydra/crystal/file.png"),:mime=>'image/png'}
        else
          url = StaticImageAggregator.find(object_relations[MEMBER_OF].first).thumbnail_info
        end
      end
      return url
    end
end
