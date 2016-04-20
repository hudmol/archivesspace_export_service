#!/bin/bash

BASEDIR=$(dirname "$0")/../

(
    cd "$BASEDIR"
    java $JAVA_OPTS -Darchivesspace-exporter=yes -Dfile.encoding=UTF-8 -cp "bin/*:java_lib/*:$CLASSPATH" org.jruby.Main -- exporter_app.rb 2>&1
)
