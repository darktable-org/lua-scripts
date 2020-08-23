#!/bin/bash
find ../../ -name "*.lua" -print | xargs grep -l bindtextdomain > POTFILES.in
