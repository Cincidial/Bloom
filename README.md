# Bloom

Process Pokemon Essentials RPGXP data (might only work on Tectonic Engine repos) (.rxdata, PBS files and sprites) to produce a sprite atlas, associated JSON metadata to handle it and a JSON file of parsed PBS data. 

For example, this can be run by calling `bundle exec ruby src/bloom.rb data/Pokemon-Tectonic-Content`

Tools required to build
    - Ruby & Bundle
        - If the `eidolon` gem has disapeared I'll commit my local to this repo
    - image magick for it's `convert` function