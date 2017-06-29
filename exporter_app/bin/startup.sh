#!/bin/bash

BASEDIR=$(dirname "$0")/../

export GEM_HOME="$BASEDIR/gems"
export GEM_PATH="$BASEDIR/gems"

cd "$BASEDIR"
mkdir -p logs
exec java $JAVA_OPTS -Darchivesspace-exporter=yes -Dfile.encoding=UTF-8 -cp "bin/*:java_lib/*:$CLASSPATH" org.jruby.Main -- exporter_app.rb 2>logs/exporter_app.err
