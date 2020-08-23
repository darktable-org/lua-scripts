#!/bin/bash
for i in `cat LINGUAS` ; do if [[ ! -d  $i ]] ; then mkdir $i ;  fi ; for j in `cat POTFILES.in` ; do if [[ -e $i/`basename $j` ]] ; then xgettext -L lua --from-code=UTF-8 -j $j -o $i/`basename $j .lua`.po ; else xgettext -L lua --from-code=UTF-8 $j -o $i/`basename $j .lua`.po ; fi; done; done
