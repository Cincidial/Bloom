# frozen_string_literal: true

# Module for some static analysis to help figure out what the data provides and what each object should do in totality
module Schema
  def self.build_schema(json_data)
    result = {}
    json_data.each do |k1, v1| # 'PBS' level
      next if k1 == :Atlas # We don't need to schema the atlas as that schema is built in Bloom

      result[k1] = {}
      v1.each do |k2, v2| # 'Abilities' level
        view = result[k1][k2] = {}
        v2.each_value do |v3| # An actual 'abilty'
          v3.each do |k4, v4| # The keys in the 'ability'
            view[k4] ||= []
            view[k4] |= [infer_schema(v4)]
          end
        end
      end
    end

    result
  end

  private_class_method def self.infer_schema(obj)
    case obj
    when Hash
      obj.transform_values { |v| infer_schema(v) }
    when Array
      obj.map { |v| infer_schema(v) }.uniq
    else
      obj.class
    end
  end
end
