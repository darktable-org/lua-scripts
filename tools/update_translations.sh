#!/bin/bash
find ../../ -name "*.lua" -print | xargs grep -l bindtextdomain > POTFILES.in

for i in `cat LINGUAS`
  do 
    if [[ ! -d  $i ]] 
      then mkdir $i 
    fi
    for j in `cat POTFILES.in` 
      do 
        if [[ -e $i/`basename $j .lua`.po ]] 
          then 
            po=`basename $j .lua`.po
            if [[ `stat -c %Y $j` -gt `stat -c %Y $i/$po` ]]
              then 
                xgettext -L lua --from-code=UTF-8 -j $j -o $i/`basename $j .lua`.po 
            fi
        else 
          xgettext -L lua --from-code=UTF-8 $j -o $i/`basename $j .lua`.po 
        fi
    done
done
for i in `cat LINGUAS`
  do 
    perl -p -i -e 's/PACKAGE VERSION/darktable lua-scripts/' $i/* 
    perl -p -i -e "s/guage: \\\n/guage: $i\\\n/" $i/* 
    perl -p -i -e 's/CHARSET/UTF-8/' $i/* 
done

rm -f POTFILES.in
