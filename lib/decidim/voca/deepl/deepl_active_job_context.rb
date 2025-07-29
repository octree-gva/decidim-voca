module Decidim
  module Voca
    module DeeplActiveJobContext
    extend ActiveSupport::Concern
    
    included do
      alias_method :voca_serialize_without_deepl, :serialize
      alias_method :voca_deserialize_without_deepl, :deserialize

      def serialize
        voca_serialize_without_deepl.merge('deepl_context' => Decidim::Voca::DeeplContext.attributes)
      end
      def deserialize(job_data)
        Decidim::Voca::DeeplContext.attributes = job_data['deepl_context']
        voca_deserialize_without_deepl(job_data)
      end
    end
  end
end
end