#!/usr/bin/env bash

ws=`dirname $0`
cd ${ws}
bundle && bundle exec rackup -E production -p 9292 -o 0.0.0.0 -s thin