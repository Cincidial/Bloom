# frozen_string_literal: true

require 'eidolon'

def marshal_all(rxdata_path)
  Eidolon.build('RGSS') unless Eidolon.built?

  marshal_data = {}
  Dir.glob(rxdata_path) do |path|
    filename = File.basename(path, '.*')
    map_id = filename[-3..].to_i

    next unless map_id.positive? || filename.include?('MapInfos') || filename.include?('Tilesets')

    marshal_data[map_id.positive? ? map_id : filename] = File.open(path, 'rb') { |data| Marshal.load(data) } # rubocop:disable Security/MarshalLoad
  end

  marshal_data
end
