require "cul_image_props"
require "mime/types"
require "uri"
require "open-uri"
require "tempfile"
require "active_fedora_finders"
class GenericResource < ::ActiveFedora::Base
  extend ActiveModel::Callbacks
  include ::ActiveFedora::FinderMethods::RepositoryMethods
  include ::ActiveFedora::DatastreamCollections
  include ::Hydra::ModelMethods
  include Cul::Scv::Hydra::Models::Common
  include Cul::Scv::Hydra::Models::ImageResource
  include Cul::Scv::Fedora::UrlHelperBehavior
  include ::ActiveFedora::RelsInt

  has_and_belongs_to_many :containers, :property=>:cul_member_of, :class_name=>'ActiveFedora::Base'

  IMAGE_EXT = {"image/bmp" => 'bmp', "image/gif" => 'gif', "image/jpeg" => 'jpg', "image/png" => 'png', "image/tiff" => 'tif', "image/x-windows-bmp" => 'bmp'}
  WIDTH = RDF::URI(ActiveFedora::Predicates.find_graph_predicate(:image_width))
  LENGTH = RDF::URI(ActiveFedora::Predicates.find_graph_predicate(:image_length))

  has_datastream :name => "content", :type=>::ActiveFedora::Datastream, :versionable => true
  has_metadata :name=>"RELS-INT", :type=>ActiveFedora::RelsInt::Datastream

  def assert_content_model
    super
    add_relationship(:rdf_type, RDF::CUL.Resource.to_s)
  end

  def route_as
    "resource"
  end

  def index_type_label
    "FILE ASSET"
  end

  def thumbnail_info
    thumb = relsint.relationships(datastreams['content'],:foaf_thumb).first
    if thumb
      t_dsid = thumb.object.to_s.split('/')[-1]
      return {:url=>"#{ActiveFedora.fedora_config[:url]}/objects/#{pid}/datastreams/#{t_dsid}/content",:mime=>datastreams[t_dsid].mimeType}
    else
      return {:url=>image_url("cul_scv_hydra/crystal/file.png"),:mime=>'image/png'}
    end
  end

  def to_solr(solr_doc = Hash.new, opts={})
    solr_doc = super

    unless solr_doc["extent_ssim"] || self.datastreams["content"].nil?
      if self.datastreams["content"].dsSize.to_i > 0
        solr_doc["extent_ssim"] = [self.datastreams["content"].dsSize]
      else
        repo = ActiveFedora::Base.connection_for_pid(pid)
        ds_parms = {pid: pid, dsid: "content", method: :head}
        repo.datastream_dissemination(ds_parms) do |res|
          solr_doc["extent_ssim"] = res['Content-Length']
        end
      end
    end

    if self.zooming?
      fz = rels_int.relationships(datastreams['content'], :foaf_zooming).first.object.to_s.split('/')[-1]
      ds = datastreams[fz]
      unless ds.nil?
        rft_id = ds.controlGroup == 'E' ? datastreams[fz].dsLocation : legacy_content_path(ds,'info:fedora/datastreams/')
        solr_doc['rft_id_ss'] = rft_id
      end
    end

    solr_doc["fulltext_teim"] = []
    unless self.datastreams["fulltext"].nil?
      solr_doc["fulltext_teim"] << self.datastreams["fulltext"].content
      solr_doc["fulltext_teim"] << solr_doc["title_display_ssm"] unless solr_doc["title_display_ssm"].nil? or solr_doc["title_display_ssm"].length == 0
    end

    solr_doc
  end

  def thumbnail_info
    thumb = rels_int.relationships(datastreams['content'],:foaf_thumbnail).first
    if thumb
      t_dsid = thumb.object.to_s.split('/')[-1]
      t_url = "#{ActiveFedora.fedora_config.credentials[:url]}/objects/#{pid}/datastreams/#{t_dsid}/content"
      return {:url=>t_url,:mime=>datastreams[t_dsid].mimeType}
    elsif self.zooming?
      t_dsid = rels_int.relationships(dsuri, :foaf_zooming).first.object.to_s.split('/')[-1]
      t_parms = DJATOKA_THUMBNAIL_PARMS.merge({"rft_id" => datastreams[t_dsid].dsLocation})
      url = "#{DJATOKA_BASE_URL}?#{options.map { |key, value|  "#{CGI::escape(key.to_s)}=#{CGI::escape(value.to_s)}"}.join("&")  }"
      {:url => url, :mime => t_parms["svc.format"]}
    else
      return {:asset => "cul_scv_hydra/crystal/file.png",:mime=>'image/png'}
    end
  end

  def linkable_resources
    # let's start with the known DSIDs from lindquist, then work our way back to parsing the solrized relsint
    results = []
    if (rels = rels_int.instance_variable_get :@solr_hash)
      # this was loaded from solr
      rels.each do |dsuri, props|
        if dsuri =~ /\/content$/ or not props[FORMAT_OF_PREDICATE].blank?
          dsid =  dsuri.split('/')[-1]
          puts props.inspect
          res = datastream_as_resource(dsid, props.with_indifferent_access)
          results << res
        end
      end
    else
      content_uri = RDF::URI("info:fedora/#{self.pid}/content")
      dsuris = [content_uri]
      results = []
      # read the graph
      datastreams.each do |k, v|
        rels = rels_int.relationships(v, :format_of, content_uri)
        dsuris << rels[0].subject unless rels.blank?
      end

      dsuris.each do |dsuri|
        dsid = dsuri.to_s.split('/')[-1]
        width_rel = rels_int.relationships(dsuri, :image_width)[0]
        length_rel = rels_int.relationships(dsuri, :image_length)[0]
        extent_rel = rels_int.relationships(dsuri, :extent)[0]
        props = {extent: [], image_width: [], image_length: []}
        props[:extent] << extent_rel.object.to_s unless extent_rel.blank?
        props[:image_width] << width_rel.object.to_s unless width_rel.blank?
        props[:image_length] << length_rel.object.to_s unless length_rel.blank?
        results << datastream_as_resource(dsid, props)
      end
    end
    results
  end

  def zooming?
    (zr = rels_int.relationships(datastreams['content'], :foaf_zooming) and not zr.first.blank?)
  end

  def with_content_resource(fedora_content_filesystem_mounted=false, &block)

    content_ds = self.datastreams['content']

    if fedora_content_filesystem_mounted
      if content_ds.dsLocation =~ /^file:\//
        dsLocation = content_ds.dsLocation.sub(/^file:\/+/,'/')
        path = URI.unescape(dsLocation)
      else
        path = content_ds.dsLocation
      end

      yield(path)
    else
      internal_uri = "info:fedora/#{self.pid}/content"
      # No local fedora mount, need to download content over http[s]

      file_basename = File.basename(content_ds.dsLocation.gsub(/^file:/,''))
      file_extension = File.extname(file_basename)

      # In some cases, we actually do want to know the original extension of the file, so we'll preserve it in the temp file filename
      temp_file = Tempfile.new([file_basename, file_extension])
      begin
        parts = internal_uri.split('/')
        open(temp_file.path, 'wb') do |blob|
          repo = ActiveFedora::Base.connection_for_pid(parts[1])
          repo.datastream_dissemination({:dsid=>parts[2], :pid=>parts[1], :finished=>false}) do |res|
            res.read_body do |seg|
              blob << seg
            end
          end
        end
        yield(temp_file.path)
      ensure
        temp_file.unlink
      end
    end

  end

  private
  def datastream_as_resource(dsid, props={})
    ds = datastreams[dsid]
    raise "No resource at info:fedora/#{pid}/#{dsid}" unless ds
    res = {}
    res[:uri] = self.pid
    res[:block] = dsid
    res[:mime_type] = ds.mimeType
    res[:content_models] = ["Datastream"]
    res[:file_size] = ds.dsSize.to_s
    if res[:file_size] == "0" and props[:extent]
      res[:file_size] = (props[:extent].first || "0")
    end
    res[:size] = (res[:file_size].to_i / 1024).to_s + " Kb"
    res[:width] = (props[:image_width] and props[:image_width].first) || "0"
    res[:height] = (props[:image_length] and props[:image_length].first) || "0"
    res[:dimensions] = "#{res[:width]} x #{res[:height]}"
    base_filename = pid.gsub(/\:/,"")
    res[:filename] = base_filename + "." + dsid + "." + ds.mimeType.gsub(/^[^\/]+\//,"")
   res
  end
end
