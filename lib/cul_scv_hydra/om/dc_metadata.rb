require 'active-fedora'
module Cul
module Scv
module Hydra
module Om
  class DCMetadata < ActiveFedora::NokogiriDatastream
    include OM::XML::Document
  
    set_terminology do |t|
      t.root(:path=>"dc", :namespace_prefix=>"oai_dc",
             "xmlns:oai_dc"=>"http://www.openarchives.org/OAI/2.0/oai_dc/",
             "xmlns:dc"=>"http://purl.org/dc/elements/1.1/",
             :schema=>"http://www.openarchives.org/OAI/2.0/oai_dc.xsd")
      t.contributor(:path=>"contributor", :namespace_prefix=>"dc")
      t.coverage(:path=>"coverage", :namespace_prefix=>"dc")
      t.creator(:path=>"creator", :namespace_prefix=>"dc")
      t.date(:path=>"date", :namespace_prefix=>"dc")
      t.description(:path=>"description", :namespace_prefix=>"dc")
      t.format(:path=>"format", :namespace_prefix=>"dc")
      t.identifier(:path=>"identifier", :namespace_prefix=>"dc")
      t.language(:path=>"language", :namespace_prefix=>"dc")
      t.publisher(:path=>"publisher", :namespace_prefix=>"dc")
      t.relation(:path=>"relation", :namespace_prefix=>"dc")
      t.rights(:path=>"rights", :namespace_prefix=>"dc")
      t.source(:path=>"source", :namespace_prefix=>"dc")
      t.subject(:path=>"subject", :namespace_prefix=>"dc")
      t.title(:path=>"title", :namespace_prefix=>"dc")
      t.dc_type(:path=>"type", :namespace_prefix=>"dc")
    end
  
    def self.xml_template
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.dc(
           "xmlns:oai_dc"=>"http://www.openarchives.org/OAI/2.0/oai_dc/",
           "xmlns:dc"=>"http://purl.org/dc/elements/1.1/",
           "xmlns:xsi"=>"http://www.w3.org/2001/XMLSchema-instance"){
          xml.parent.namespace_definitions.each {|ns|
            xml.parent.namespace = ns if ns.prefix == 'oai_dc'
          }
        }
      end
      builder.doc.encoding = 'UTF-8'
      builder.doc.root["xsi:schemaLocation"] = 'http://www.openarchives.org/OAI/2.0/oai_dc/ http://www.openarchives.org/OAI/2.0/oai_dc.xsd'
      return builder.doc
    end
    def method_missing method, *args
      query = false
      _mname = method.id2name
      if _mname[-1,1] == '?'
        query = true
        _mname = _mname[0,_mname.length-1]
      end
      _msym = _mname.to_sym
      begin
        has_term = self.class.terminology.has_term?(_msym)
       
        _r = (has_term)? find_by_terms(_msym, *args) : nil
        if query
          return !( _r.nil? || _r.size()==0)
        else
          return _r
        end
      rescue
        super
      end
    end
    def update_values(*args)
      super
      self.dirty = true
    end
  end
end
end
end
end