#!/bin/bash

BASEDIR=$(dirname "$0")/../

export GEM_HOME="$BASEDIR/gems"
export GEM_PATH="$BASEDIR/gems"

cd "$BASEDIR"

java -cp 'bin/*' org.jruby.Main -S gem install bundler

java -cp 'bin/*' org.jruby.Main gems/bin/bundle install
