# frozen_string_literal: true

# Data is a hash of {k: {path: "path/to/directory/to/glob", w: width, h: height}}
def build_atlas(output_path, build_dir, data)
  magick_config = 'MAGICK_CONFIGURE_PATH="image_magick_config/"' # This is relative to the caller

  atlas_meta_hash = { artifact: File.basename(output_path) }
  atlas_rows = [[]]
  x = 0
  y = 0

  data.each do |k, glob|
    file_list = Dir.glob("#{glob[:path]}/*.png")
    width = glob[:w]
    height = glob[:h]

    atlas_meta_hash[k] = { w: width, h: height }

    max_y = 0
    file_list.each do |path|
      filename = File.basename(path, '.*')

      atlas_meta_hash[k][filename] = { x: x, y: y }
      atlas_rows.last.push("'#{path}'")
      x += width
      max_y = [max_y, height].max

      next if x < 32_768

      x = 0
      y += max_y
      max_y = 0
      atlas_rows.push([])
    end
  end

  atlas_temp_row_file_path = "#{build_dir}/atlas_temp_row.png"
  atlas_rows.each_with_index do |row, i|
    `#{magick_config} convert #{row.join(' ')} -background none +append #{atlas_temp_row_file_path}`
    `#{magick_config} convert #{i.zero? ? '' : output_path} #{atlas_temp_row_file_path} -background none -append #{output_path}`
  end

  atlas_meta_hash
end
