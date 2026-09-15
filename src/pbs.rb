# frozen_string_literal: true

# Module for handling pbs data
module Pbs
  def self.build_pbs(pbs_path)
    result = {}
    result[:Abilities] = parse_multi_line_objects(["#{pbs_path}abilities.txt", "#{pbs_path}abilities_new.txt"])
    result[:AbilitiesPrimeval] = parse_multi_line_objects(["#{pbs_path}abilities_primeval.txt"])
    result[:Achievements] = parse_multi_line_objects(["#{pbs_path}achievements.txt"])
    result[:Avatars] = parse_multi_line_objects(["#{pbs_path}avatars.txt"], %w[ID Version])
    result[:Dislikes] = parse_single_line_objects(["#{pbs_path}dislikes.txt"], %w[Key Description])
    result[:Likes] = parse_single_line_objects(["#{pbs_path}dislikes.txt"], %w[Key Description])
    result[:Traits] = parse_single_line_objects(["#{pbs_path}traits.txt"], %w[Key Description])
    result[:Items] = parse_multi_line_objects(["#{pbs_path}items.txt", "#{pbs_path}items_machine.txt"])
    result[:ItemsSuper] = parse_multi_line_objects(["#{pbs_path}items_super.txt"])
    result[:Moves] = parse_multi_line_objects(["#{pbs_path}moves.txt", "#{pbs_path}moves_new.txt"])
    result[:MovesPrimeval] = parse_multi_line_objects(["#{pbs_path}moves_primeval.txt"])
    result[:Tribes] = parse_single_line_objects(["#{pbs_path}tribes.txt"], %w[Key Count Name Description])
    result[:Types] = parse_multi_line_objects(["#{pbs_path}types.txt"])
    pokemon = result[:Pokemon] = parse_multi_line_objects(["#{pbs_path}pokemon.txt"])
    result[:PokemonForms] = parse_multi_line_objects(["#{pbs_path}pokemonforms.txt"], %w[ID Form])
    trainers = result[:Trainers] = parse_multi_line_objects(["#{pbs_path}trainers.txt"], %w[Type Name Version], %w[Pokemon ID Level])
    result[:TrainersTypes] = parse_multi_line_objects(["#{pbs_path}trainertypes.txt"])
    encounters = result[:Encounters] = parse_encounters_file("#{pbs_path}encounters.txt")

    # Post Processing
    post_process_evolutions(pokemon)
    # pp pokemon

    # TODO: Generate a schema to attach to each result
    # TODO: Add post processing for moves (later evolutions take the priors list if they don't have anything beyond a level 0 evolution move?) (will add quite a lot of file size, but probaly worth it)
    #   And line moves for TMs?
    # TODO: Add post processing for tribes
    # TODO: Add post processing to trainers to replace ability index with its key
    # TODO: Post processing to add the name of the location to the encounters list using the rxdata

    result
  end

  # Parses files that have a [object_key] and any number of k=v below them, including repeating sub objects
  #
  # @param paths [Array of strings] - The paths to process
  # @param key_split_keys [Array of strings] - The keys (in order) to use and add to the object when splitting the [object_key]
  # @param sub_obj_kv_split [Array of strings] - The keys (in order) to use and add to a sub object when splitting its sub_obj_key=x,y,z line. sub_obj_key should be the first value in the array
  # @return [Array of objects] - The results
  private_class_method def self.parse_multi_line_objects(paths = [], key_split_keys = [], sub_obj_kv_split = [])
    sub_obj_key = sub_obj_kv_split[0] if sub_obj_kv_split.length.positive?
    results = {}

    paths.each do |path|
      obj = {}
      File.foreach(path, mode: 'r:bom|utf-8', chomp: true) do |line|
        line = line.strip
        next if line.start_with?('#')

        line = line.sub(/#.*/, '').rstrip
        if line.start_with?('[')
          if obj.key?(:Key)
            results[obj[:Key]] = obj
            obj.delete(:Key)
            obj = {}
          end
          obj[:Key] = line[/\[(.*?)\]/, 1]

          key_split = obj[:Key].split(',')
          if key_split.length > 1
            key_split.each_with_index do |x, i|
              x = Integer(x) if Integer(x, exception: false)
              obj["__Key_#{key_split_keys[i]}"] = x
            end
          end
        elsif !sub_obj_key.nil? && line.start_with?(sub_obj_key)
          obj[sub_obj_key] = [] unless obj.key?(sub_obj_key)
          sub_obj = {}

          k, v = parse_kv(line)
          v.each_with_index do |x, i| # Assume the sub object line is an array split
            sub_obj[sub_obj_kv_split[i + 1]] = x
          end
          obj[k].append(sub_obj)
        else
          obj_to_add_to = obj
          obj_to_add_to = obj[sub_obj_key].last if obj.key?(sub_obj_key)

          k, v = parse_kv(line)
          obj_to_add_to[k] = v
        end
      end

      results[obj[:Key]] = obj
      obj.delete(:Key)
    end

    results
  end

  # Assumes the first key in the split is the key for the object in the hash
  private_class_method def self.parse_single_line_objects(paths = [], split_keys = [])
    results = {}
    paths.each do |path|
      File.foreach(path, mode: 'r:bom|utf-8', chomp: true) do |line|
        obj = parse_single_line_obj(line, split_keys)
        results[obj[split_keys[0]]] = obj
        obj.delete(split_keys[0])
      end
    end

    results
  end

  private_class_method def self.parse_encounters_file(path)
    results = {}
    obj = { Tables: [] }

    File.foreach(path, mode: 'r:bom|utf-8', chomp: true) do |line|
      next if line.start_with?('#')

      line = line.sub(/#.*/, '').rstrip
      stripped_line = line.strip
      if line.start_with?('[') # Map
        if obj.key?(:Key)
          results[obj[:Key]] = obj
          obj.delete(:Key)
          obj = { Tables: [] }
        end
        obj[:Key] = stripped_line[/\[(.*?)\]/, 1]
      elsif line.start_with?('    ') # Encounter
        encounter = parse_single_line_obj(stripped_line, %w[Weight Mon_Form MinLvl MaxLvl])
        mon, form = encounter['Mon_Form'].split('_')
        encounter.delete('Mon_Form')

        encounter[:Pokemon] = mon
        encounter[:Form] = form unless form.nil?
        obj[:Tables].last[:Encounters].append(encounter)
      else # Table
        table = parse_single_line_obj(stripped_line, %w[Zone Rate MinLvlCap NormalLvlCap])
        table[:Encounters] = []
        obj[:Tables].append(table)
      end
    end

    results[obj[:Key]] = obj
    obj.delete(:Key)
    results
  end

  private_class_method def self.parse_single_line_obj(line, split_keys)
    split = line.split(',')
    obj = {}

    split.each_with_index do |x, i|
      obj[split_keys[i]] = cast_value(x)
    end
    obj
  end

  private_class_method def self.parse_kv(str)
    split = str.split('=')
    id = split[0].strip
    value = split[1].strip

    [id, cast_value(value)]
  end

  private_class_method def self.cast_value(value)
    if Integer(value, exception: false) # Pure integer value, convert it
      return Integer(value)
    elsif Float(value, exception: false) # Pure float value, convert it
      return Float(value)
    elsif !value.match?(/\s/) && value.include?(',') # Must be an array, descriptions with a ',' have whitespace
      return value.split(',').map do |x| # Convert integer elements to actual int values instead of string within the array
        if Integer(x, exception: false)
          Integer(x)
        else
          x
        end
      end
    end

    value
  end

  private_class_method def self.post_process_evolutions(pokemon)
    evolutions_key = 'Evolutions'

    # Convert evolutions to an object based array
    pokemon.each_key do |mon|
      next unless pokemon[mon][evolutions_key]

      evolutions = pokemon[mon][evolutions_key]
      obj_based_evos = []
      i = 0
      while i < evolutions.length
        obj_based_evos.append({ Pokemon: evolutions[0], Method: evolutions[1], Value: evolutions[2] })
        i += 3
      end

      pokemon[mon][evolutions_key] = obj_based_evos
    end

    # The final pokemon will have nothing to evolve into, so we can work backwards from there (ensures the list generates no matter the pokedex order)
    # Only need to track the prevo on every mon, so that it can referenced and the tree built from there as needed client side

    pokemon_with_evos = pokemon.select { |_, v| v.key?(evolutions_key) }
    pokemon.each_key do |mon|
      prevo = pokemon_with_evos.reject { |_, v| v[evolutions_key].select { |x| x[:Pokemon] == mon }.empty? }.keys
      next if prevo.empty?

      pokemon[mon][:Prevo] = prevo
    end
  end
end
