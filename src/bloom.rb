# frozen_string_literal: true

################### Switch to false when testing other stuff, because this takes some time to run
run_img_cmds = true
###################

require 'json'
require_relative 'schema'
require_relative 'repo'
require_relative 'pbs'
require_relative 'rxdata'
require_relative 'atlas'

usage_message = "Run with arguments: <path to the game repo> <output path (a 'BloomArtifacts' folder will be made here. No argument assumes the current directory)>"
abort(usage_message) if ARGV.empty?

repo_path = ARGV[0]
rxdata_path = "#{repo_path}/Data/*.rxdata"

output_directory_path = ARGV[1].nil? || ARGV[1].empty? ? './BloomArtifacts' : "#{ARGV[1]}/BloomArtifacts"
`mkdir -p #{output_directory_path}`

build_dir = './build'
`mkdir -p #{build_dir}`

### Process hardcoded repo data
repo_data = Repo.build_repo

### Process rxdata files
marshal_data = RxData.marshal_all(rxdata_path)
# pp marshal_data

### Process pbs files
pbs_data = Pbs.build_pbs("#{repo_path}/PBS/", marshal_data, repo_data)

### Build Sprite atlases
atlas_metadata_hash = {}
if run_img_cmds
  sprite_atlas_build_data = { # Anything with {---} will be replaced by the appropriate value
    Icon: {
      repo_path: ['Graphics/Pokemon/Icons'],
      path: "#{build_dir}/icons",
      clean_cmd: ['-crop {w}x{h}+0+0 +repage'],
      w: 64,
      h: 64
    },
    Front: {
      repo_path: ['Graphics/Pokemon/Front'],
      path: "#{build_dir}/fronts",
      clean_cmd: ['-resize {w}x{h} +repage'],
      w: 160,
      h: 160
    },
    Item: {
      repo_path: ['Graphics/Items'],
      path: "#{build_dir}/items",
      clean_cmd: ['-resize {w}x{h} +repage'],
      w: 48,
      h: 48
    },
    Trainer: {
      repo_path: ['Graphics/Trainers'],
      path: "#{build_dir}/trainers",
      clean_cmd: ['-resize {w}x{h} +repage'],
      w: 160,
      h: 160
    },
    Overworld: {
      repo_path: ['Graphics/Characters', 'Graphics/Characters/Followers'],
      path: "#{build_dir}/overworld",
      clean_cmd: ['-resize 256x256 -crop {w}x{h}+0+0 +repage', '-resize 256x256 -crop {w}x{h}+0+0 +repage'],
      w: 64,
      h: 256 # Take the first vertical column so that we can use the directional sprites
    },
    MoveCategory: {
      path: "#{build_dir}/move_categories",
      clean_cmd: ["cp -r ./global_imgs/move_categories/ #{build_dir}/"],
      w: 59,
      h: 39
    },
    Type: {
      path: "#{build_dir}/types",
      clean_cmd: ["mogrify -path #{build_dir}/types -format png -resize {w}x{h} -background none ./global_imgs/types/pokemon-type-icons-main/icons/*.svg"],
      w: 128,
      h: 128
    }
  }

  # Initial cleanup of images
  pids = []
  sprite_atlas_build_data.each_value do |data|
    `mkdir -p #{data[:path]}`
    data[:clean_cmd].each_with_index do |cmd, i|
      full_cmd = cmd
      if data.key?(:repo_path)
        repo_sub_path = data[:repo_path][i]
        full_cmd = "mogrify -path #{data[:path]} #{cmd} #{repo_path}/#{repo_sub_path}/*.png"
      end

      full_cmd = full_cmd.gsub('{w}', data[:w].to_s)
      full_cmd = full_cmd.gsub('{h}', data[:h].to_s)
      pids << fork do
        exec(full_cmd)
      end
    end
  end
  pids.each { |pid| Process.wait(pid) }

  # Build the sprite atlas
  sprite_atlas_output = "#{output_directory_path}/sprite_atlas.png"
  atlas_metadata_hash[:sprite_atlas] = build_atlas(sprite_atlas_output, build_dir, sprite_atlas_build_data)
end

### Finalize the JSON output
json = {
  PBS: pbs_data,
  RxData: marshal_data,
  Atlas: atlas_metadata_hash
}
json[:Schema] = Schema.build_schema(json)
File.write("#{output_directory_path}/data.json", JSON.generate(json))
