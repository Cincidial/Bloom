# frozen_string_literal: true

require 'eidolon'

# Module for handling the RxData files
module RxData
  def self.marshal_all(rxdata_path)
    Eidolon.build('RGSS') unless Eidolon.built?

    map_info = {}
    maps = {}
    Dir.glob(rxdata_path) do |path|
      filename = File.basename(path, '.*')
      map_id = filename[-3..].to_i

      next unless map_id.positive? || filename.include?('MapInfos') || filename.include?('Tilesets')

      data = File.open(path, 'rb') { |data| Marshal.load(data) } # rubocop:disable Security/MarshalLoad
      map_info = parse_mapinfos(data) if filename.include?('MapInfos')
      maps[map_id] = parse_map(map_id, data) if map_id.positive?
      # marshal_data[map_id.positive? ? map_id : filename] = data
    end

    maps.each do |k, v|
      v.merge!(map_info[k])
    end
    maps
  end

  private_class_method def self.parse_mapinfos(data)
    result = {}
    data.each do |k, v|
      result[k] = {
        Name: v.name,
        ListOrder: v.order,
        FromMapId: v.parent_id,
        ToMapIds: data.select { |_, x| x.parent_id == k }.keys
      }
    end
    result
  end

  private_class_method def self.parse_map(id, data)
    result = {}
    # pp data if id == 1
    result
  end
end
