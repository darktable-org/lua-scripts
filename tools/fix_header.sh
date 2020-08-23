#!/bin/bash
for i in `cat LINGUAS` ; do perl -p -i -e 's/PACKAGE VERSION/darktable lua-scripts/' $i/* ; perl -p -i -e "s/guage: \\\n/guage: $i\\\n/" $i/* ; perl -p -i -e 's/CHARSET/UTF-8/' $i/* ; done
